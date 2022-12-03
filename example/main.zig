const js = @import("zig-js");

export fn set_title() void {
    set_title_() catch unreachable;
}

export fn alert() void {
    alert_() catch unreachable;
}

fn set_title_() !void {
    const doc = try js.global.get(js.Object, "document");
    defer doc.deinit();

    try doc.set("title", js.string("Hello!"));
}

fn alert_() !void {
    const alert_fn = try js.Value.global.get("alert");
    defer alert_fn.deinit();

    const msg = js.Value.init(js.String.init("Hello, world!"));
    defer msg.deinit();

    _ = try alert_fn.apply(.undefined, &[_]js.Value{msg});
}
