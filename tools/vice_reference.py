"""Offline VICE binary-monitor reference. Never loaded by the GameMaker game."""
from pathlib import Path
import socket,struct,subprocess,time,json
ROOT=Path(__file__).resolve().parents[1]

class Reference:
    def __init__(self):
        self.id=0;self.events=[]
        with socket.socket() as reserve:reserve.bind(('127.0.0.1',0));port=reserve.getsockname()[1]
        exe=next((ROOT/'tools/vendor/vice').rglob('x64sc.exe'))
        self.log=open(ROOT/'source/local/captures/binary-reference.log','w')
        args=[str(exe),'-default','-console','-pal','+sound','-warp','-binarymonitor',
              '-binarymonitoraddress',f'127.0.0.1:{port}']
        self.process=subprocess.Popen(args,cwd=exe.parent,stdout=self.log,stderr=subprocess.STDOUT,
            creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        for _ in range(100):
            if self.process.poll() is not None:raise RuntimeError('VICE exited; inspect binary-reference.log')
            try:self.socket=socket.create_connection(('127.0.0.1',port),timeout=1);break
            except OSError:time.sleep(.05)
        else:self.close();raise TimeoutError('VICE monitor did not open')
        self.socket.settimeout(15);self.command(0x81)
        self.banks={}
        body=self.command(0x82);pos=2
        for _ in range(int.from_bytes(body[:2],'little')):
            size=body[pos];item=body[pos+1:pos+1+size];pos+=size+1
            self.banks[item[3:3+item[2]].decode()]=int.from_bytes(item[:2],'little')
        self.register_ids={}
        body=self.command(0x83,b'\0');pos=2
        for _ in range(int.from_bytes(body[:2],'little')):
            size=body[pos];item=body[pos+1:pos+1+size];pos+=size+1
            self.register_ids[item[3:3+item[2]].decode()]=item[0]
    def exact(self,n):
        data=b''
        while len(data)<n:
            chunk=self.socket.recv(n-len(data))
            if not chunk:raise ConnectionError('VICE closed monitor connection')
            data+=chunk
        return data
    def receive(self):
        header=self.exact(12)
        if header[:2]!=b'\x02\x02':raise ValueError('Unexpected monitor protocol')
        length,kind,error,request=struct.unpack('<IBBI',header[2:])
        return kind,error,request,self.exact(length)
    def command(self,kind,body=b''):
        self.id+=1;request=self.id
        self.socket.sendall(struct.pack('<BBIIB',2,2,len(body),request,kind)+body)
        while True:
            response=self.receive()
            if response[2]==request:
                if response[1]:raise RuntimeError(f'VICE command {kind:02x}: error {response[1]:02x}')
                return response[3]
            self.events.append(response)
    def memory(self,start,end,bank='ram'):
        return self.command(1,struct.pack('<BHHBH',0,start,end,0,self.banks[bank]))[2:]
    def write(self,start,data,bank='ram'):
        self.command(2,struct.pack('<BHHBH',0,start,start+len(data)-1,0,self.banks[bank])+bytes(data))
    def registers(self):
        body=self.command(0x31,b'\0');pos=2;values={};reverse={v:k for k,v in self.register_ids.items()}
        for _ in range(int.from_bytes(body[:2],'little')):
            size=body[pos];item=body[pos+1:pos+1+size];pos+=size+1
            values[reverse.get(item[0],str(item[0]))]=int.from_bytes(item[1:],'little')
        return values
    def set_registers(self,**values):
        body=struct.pack('<BH',0,len(values))
        for name,value in values.items():body+=struct.pack('<BBH',3,self.register_ids[name],value)
        self.command(0x32,body)
    def load_snapshot(self,path):
        name=str(Path(path).resolve()).encode();self.command(0x42,bytes([len(name)])+name)
    def wait_stopped(self):
        for i,response in enumerate(self.events):
            if response[0]==0x62:
                self.events.pop(i);return
        while True:
            response=self.receive()
            if response[0]==0x62:return
            self.events.append(response)
    def step(self,count):
        self.events=[];self.command(0x71,struct.pack('<BH',0,count));self.wait_stopped()
    def until(self,address):
        # VICE 3.10 resumes after a temporary checkpoint in this configuration.
        # Keep the checkpoint persistent until stopped, then remove it explicitly.
        body=self.command(0x12,struct.pack('<HHBBBBB',address,address,1,1,4,0,0))
        checkpoint=int.from_bytes(body[:4],'little');self.events=[]
        self.command(0xaa);hit=False
        while True:
            response=self.events.pop(0) if self.events else self.receive()
            if response[0]==0x11 and int.from_bytes(response[3][:4],'little')==checkpoint and response[3][4]:hit=True
            if response[0]==0x62 and hit:
                self.last_stop=int.from_bytes(response[3][:2],'little')
                self.command(0x13,struct.pack('<I',checkpoint))
                if self.registers()['PC']!=address:raise RuntimeError('Reference advanced beyond its requested checkpoint')
                return
    def close(self):
        if hasattr(self,'socket'):
            try:self.command(0xbb)
            except (OSError,ConnectionError):pass
            self.socket.close()
        if hasattr(self,'process'):
            try:self.process.wait(timeout=3)
            except subprocess.TimeoutExpired:self.process.terminate();self.process.wait(timeout=3)
        if hasattr(self,'log'):self.log.close()
    def __enter__(self):return self
    def __exit__(self,*_):self.close()

if __name__=='__main__':
    with Reference() as ref:
        print('banks',ref.banks,'registers',ref.register_ids,flush=True)
        ref.load_snapshot(ROOT/'source/local/captures/ln1-game.vsf')
        print('loaded',ref.registers(),'VIC',ref.memory(0xd000,0xd03f,'io').hex(' '),flush=True)
        ref.until(0xbd26)
        print('input boundary',hex(ref.last_stop),ref.registers(),'actors',ref.memory(0x50,0x78).hex(' '),flush=True)
