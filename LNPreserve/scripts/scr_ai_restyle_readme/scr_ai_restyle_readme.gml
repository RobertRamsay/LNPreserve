/// AI RESTYLE - README
//
// Live AI restyling of your game screen while you play.
//
// SETUP
// 1. Place one obj_ai_restyle in your first room (it is persistent),
//    or create it from any startup object:
//        instance_create_depth(0, 0, 0, obj_ai_restyle);
// 2. Run the helper (gm_restyle_server.py, shipped next to this package):
//        python gm_restyle_server.py --backend local     (NVIDIA GPU, free)
//        python gm_restyle_server.py --backend decart    (cloud, needs DECART_API_KEY)
//    The game retries the connection every 2 seconds, so start order doesn't matter.
//
// KEYS
//    F2   toggle AI view
//    TAB  next preset style
//    F3   type a custom style
//    F4   hide / show the status overlay
//
// SETTINGS (top of obj_ai_restyle Create event)
//    host_address / host_port   where the helper runs
//    cap_w / cap_h              frame size sent to the AI (smaller = faster)
//    prompt_list                preset styles
//
// NOTES
// - The object takes over drawing application_surface in Post Draw.
//   If your game already draws application_surface itself, disable that.
// - Draw GUI is drawn on top of the AI image, so HUD and text stay crisp.
// - If reds and blues are swapped, run the helper with --pixel-order BGRA.
// - Decart bills while the helper is connected. F2 only hides the view,
//   so close the helper when you are done.
