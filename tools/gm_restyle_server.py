"""
gm_restyle_server.py
Live AI restyle helper for GameMaker.

GameMaker sends raw frames over a local TCP socket. This helper restyles them
with either a local StreamDiffusion model (NVIDIA GPU) or Decart's cloud
Lucy Restyle model, and sends the restyled frame straight back.

Usage:
    python gm_restyle_server.py --backend local
    python gm_restyle_server.py --backend decart      (needs DECART_API_KEY)

Protocol (little-endian). Every packet is [u8 type][u32 payload_length][payload]
    GM -> helper   1 FRAME    payload = [u16 w][u16 h][w*h*4 pixel bytes]
    GM -> helper   2 PROMPT   payload = UTF-8 text
    helper -> GM   1 FRAME    payload = [u16 w][u16 h][w*h*4 pixel bytes]
    helper -> GM   3 NOFRAME  payload empty (nothing new yet, send the next frame)
    helper -> GM   4 STATUS   payload = UTF-8 text
"""

import argparse
import asyncio
import os
import socket
import struct
import time

from PIL import Image

PKT_FRAME = 1
PKT_PROMPT = 2
PKT_NOFRAME = 3
PKT_STATUS = 4


def swap_red_blue(img):
    c0, c1, c2, c3 = img.split()
    return Image.merge("RGBA", (c2, c1, c0, c3))


# ---------------------------------------------------------------------------
# Local backend: StreamDiffusion on your own NVIDIA GPU
# ---------------------------------------------------------------------------
class LocalBackend:
    name = "local StreamDiffusion"

    def __init__(self, args):
        self.args = args
        self.stream = None
        self.postprocess_image = None
        self.prompt = args.prompt
        self.pending_prompt = None

    async def start(self):
        await asyncio.to_thread(self._load)

    def _load(self):
        import torch
        from diffusers import AutoencoderTiny, StableDiffusionPipeline
        from streamdiffusion import StreamDiffusion
        from streamdiffusion.image_utils import postprocess_image

        self.postprocess_image = postprocess_image
        print("Loading model:", self.args.model)
        pipe = StableDiffusionPipeline.from_pretrained(
            self.args.model, torch_dtype=torch.float16
        ).to("cuda")

        t_index_list = []
        for value in self.args.t_index.split(","):
            t_index_list.append(int(value.strip()))

        self.stream = StreamDiffusion(
            pipe,
            t_index_list=t_index_list,
            torch_dtype=torch.float16,
            width=self.args.width,
            height=self.args.height,
            cfg_type="none",
        )
        if self.args.lcm:
            self.stream.load_lcm_lora()
            self.stream.fuse_lora()

        self.stream.vae = AutoencoderTiny.from_pretrained("madebyollin/taesd").to(
            device=pipe.device, dtype=pipe.dtype
        )
        try:
            pipe.enable_xformers_memory_efficient_attention()
        except Exception:
            print("xformers not available, continuing without it")

        self._prepare(self.prompt)

        print("Warming up...")
        warm = Image.new("RGB", (self.args.width, self.args.height), (64, 64, 64))
        for _ in range(4):
            self.stream(warm)
        print("Local model ready")

    def _prepare(self, prompt):
        self.stream.prepare(prompt=prompt, num_inference_steps=50, guidance_scale=1.0)

    def _process_sync(self, rgb):
        if self.pending_prompt is not None:
            self.prompt = self.pending_prompt
            self.pending_prompt = None
            self._prepare(self.prompt)
        model_in = rgb.resize((self.args.width, self.args.height), Image.BILINEAR)
        out = self.stream(model_in)
        return self.postprocess_image(out, output_type="pil")[0]

    async def set_prompt(self, text):
        # Applied on the inference thread before the next frame
        self.pending_prompt = text

    async def process(self, rgb):
        return await asyncio.to_thread(self._process_sync, rgb)

    async def stop(self):
        return


# ---------------------------------------------------------------------------
# Cloud backend: Decart Lucy Restyle (realtime)
# ---------------------------------------------------------------------------
class DecartBackend:
    name = "Decart Lucy Restyle"

    def __init__(self, args):
        self.args = args
        self.rtc = None
        self.client = None
        self.realtime = None
        self.model = None
        self.source = None
        self.latest_input = None
        self.latest_output = None
        self.output_serial = 0
        self.sent_serial = 0
        self.push_task = None
        self.consume_tasks = []
        self.running = False

    async def start(self):
        from decart import DecartClient, models
        from decart.realtime import RealtimeClient, RealtimeConnectOptions
        from decart.types import ModelState, Prompt
        from livekit import rtc

        self.rtc = rtc
        api_key = os.environ.get("DECART_API_KEY", "")
        if api_key == "":
            raise SystemExit("Set the DECART_API_KEY environment variable first")

        self.client = DecartClient(api_key=api_key)
        self.model = models.realtime(self.args.decart_model)
        self.source = rtc.VideoSource(self.model.width, self.model.height)
        track = rtc.LocalVideoTrack.create_video_track("gamemaker_input", self.source)

        options = RealtimeConnectOptions(
            model=self.model,
            on_remote_stream=self._on_remote_stream,
            initial_state=ModelState(prompt=Prompt(text=self.args.prompt, enhance=True)),
        )
        print("Connecting to Decart:", self.args.decart_model)
        self.realtime = await RealtimeClient.connect(
            base_url=self.client.realtime_base_url,
            api_key=self.client.api_key,
            local_track=track,
            options=options,
        )
        self.realtime.on("connection_change", self._on_connection_change)
        self.realtime.on("error", self._on_error)

        self.running = True
        self.push_task = asyncio.create_task(self._push_loop())
        print("Decart connected (billing runs while this helper is connected)")

    def _on_connection_change(self, state):
        print("Decart connection:", state)

    def _on_error(self, error):
        print("Decart error:", error)

    def _on_remote_stream(self, track):
        task = asyncio.create_task(self._consume(track))
        self.consume_tasks.append(task)

    async def _consume(self, track):
        async for event in self.rtc.VideoStream(track):
            frame = event.frame.convert(self.rtc.VideoBufferType.RGBA)
            self.latest_output = Image.frombytes(
                "RGBA", (frame.width, frame.height), bytes(frame.data)
            )
            self.output_serial += 1

    async def _push_loop(self):
        interval = 1.0 / float(self.model.fps)
        while self.running:
            if self.latest_input is not None:
                frame = self.rtc.VideoFrame(
                    width=self.model.width,
                    height=self.model.height,
                    type=self.rtc.VideoBufferType.RGB24,
                    data=self.latest_input,
                )
                self.source.capture_frame(frame)
            await asyncio.sleep(interval)

    async def set_prompt(self, text):
        try:
            await self.realtime.set_prompt(text, enhance=True)
        except Exception as err:
            print("Prompt change failed:", err)

    async def process(self, rgb):
        resized = rgb.resize((self.model.width, self.model.height), Image.BILINEAR)
        self.latest_input = resized.tobytes()

        # Wait briefly for a fresh output frame so GameMaker isn't spinning
        deadline = time.monotonic() + 0.05
        while self.output_serial == self.sent_serial and time.monotonic() < deadline:
            await asyncio.sleep(0.003)

        if self.output_serial == self.sent_serial:
            return None
        if self.latest_output is None:
            return None
        self.sent_serial = self.output_serial
        return self.latest_output.convert("RGB")

    async def stop(self):
        self.running = False
        if self.realtime is not None:
            await self.realtime.disconnect()
        if self.client is not None:
            await self.client.close()


# ---------------------------------------------------------------------------
# TCP server
# ---------------------------------------------------------------------------
async def send_packet(writer, ptype, payload):
    writer.write(struct.pack("<BI", ptype, len(payload)) + payload)
    await writer.drain()


class FrameStats:
    def __init__(self):
        self.reset()
        self.last_print = time.monotonic()

    def reset(self):
        self.frames = 0
        self.ai_ms = 0.0
        self.total_ms = 0.0

    def add(self, ai_ms, total_ms):
        self.frames += 1
        self.ai_ms += ai_ms
        self.total_ms += total_ms
        now = time.monotonic()
        elapsed = now - self.last_print
        if elapsed >= 2.0:
            if self.frames > 0:
                print("AI %.1f fps | model %.0f ms | per frame %.0f ms" % (
                    self.frames / elapsed, self.ai_ms / self.frames, self.total_ms / self.frames))
            self.reset()
            self.last_print = now


STATS = FrameStats()


async def handle_frame(writer, payload, backend, args):
    t_start = time.perf_counter()
    w, h = struct.unpack("<HH", payload[:4])
    pixels = payload[4:]
    if len(pixels) != w * h * 4:
        await send_packet(writer, PKT_STATUS, b"bad frame size")
        await send_packet(writer, PKT_NOFRAME, b"")
        return

    img = Image.frombytes("RGBA", (w, h), pixels)
    if args.pixel_order == "BGRA":
        img = swap_red_blue(img)
    rgb = img.convert("RGB")

    out = None
    t_ai = time.perf_counter()
    try:
        out = await backend.process(rgb)
    except Exception as err:
        print("Restyle failed:", err)
    ai_ms = (time.perf_counter() - t_ai) * 1000.0

    if out is None:
        await send_packet(writer, PKT_NOFRAME, b"")
        return

    out_rgba = out.resize((w, h), Image.BILINEAR).convert("RGBA")
    if args.pixel_order == "BGRA":
        out_rgba = swap_red_blue(out_rgba)
    await send_packet(writer, PKT_FRAME, struct.pack("<HH", w, h) + out_rgba.tobytes())
    STATS.add(ai_ms, (time.perf_counter() - t_start) * 1000.0)


async def handle_client(reader, writer, backend, args):
    sock = writer.get_extra_info("socket")
    if sock is not None:
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)

    print("GameMaker connected")
    await send_packet(writer, PKT_STATUS, ("Helper ready: " + backend.name).encode("utf-8"))
    try:
        while True:
            header = await reader.readexactly(5)
            ptype, plen = struct.unpack("<BI", header)
            payload = b""
            if plen > 0:
                payload = await reader.readexactly(plen)

            if ptype == PKT_FRAME:
                await handle_frame(writer, payload, backend, args)
            elif ptype == PKT_PROMPT:
                text = payload.decode("utf-8", errors="replace")
                print("New style:", text)
                asyncio.create_task(backend.set_prompt(text))
                await send_packet(writer, PKT_STATUS, ("Style: " + text).encode("utf-8"))
    except (asyncio.IncompleteReadError, ConnectionResetError):
        print("GameMaker disconnected")
    finally:
        writer.close()


async def main():
    parser = argparse.ArgumentParser(description="Live AI restyle helper for GameMaker")
    parser.add_argument("--backend", choices=["local", "decart"], default="local")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=5577)
    parser.add_argument("--prompt", default="oil painting, dramatic lighting")
    parser.add_argument("--pixel-order", choices=["RGBA", "BGRA"], default="RGBA",
                        help="Switch to BGRA if reds and blues come out swapped")
    # Local options
    parser.add_argument("--model", default="stabilityai/sd-turbo")
    parser.add_argument("--width", type=int, default=640)
    parser.add_argument("--height", type=int, default=384)
    parser.add_argument("--t-index", default="25,45",
                        help="Lower first number = stronger restyle, higher = closer to the game")
    parser.add_argument("--lcm", action="store_true",
                        help="Use for non-turbo SD1.5 models (loads the LCM LoRA)")
    # Decart options
    parser.add_argument("--decart-model", default="lucy-restyle-2")
    args = parser.parse_args()

    if args.backend == "local":
        backend = LocalBackend(args)
    else:
        backend = DecartBackend(args)

    print("Starting backend:", backend.name)
    await backend.start()

    async def on_connect(reader, writer):
        await handle_client(reader, writer, backend, args)

    server = await asyncio.start_server(on_connect, args.host, args.port)
    print("Listening on", args.host, args.port, "- run your GameMaker game now")
    try:
        async with server:
            await server.serve_forever()
    finally:
        await backend.stop()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("Stopped")
