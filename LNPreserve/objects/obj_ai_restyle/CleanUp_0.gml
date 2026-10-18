/// obj_ai_restyle - Clean Up

network_destroy(sock);
buffer_delete(send_buf);
buffer_delete(rx_buf);
buffer_delete(shift_buf);
if (surface_exists(cap_surf)) {
    surface_free(cap_surf);
}
if (surface_exists(result_surf)) {
    surface_free(result_surf);
}
application_surface_draw_enable(true);
