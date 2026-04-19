package main

import "core:fmt"
import "core:math"
import "core:mem"
import "core:strings"

import rl "vendor:raylib"
import mu "vendor:microui"

mu_ctx: mu.Context
atlas_texture: rl.Texture2D
window_w: i32 = 1024
window_h: i32 = 768

Button :: struct {
    label: string,
    hotkeys: []rl.KeyboardKey,
    action: proc(calc: ^Calculator),
}

CALCULATOR_BUTTONS :: []Button{
    Button{"<-",  {.BACKSPACE},     proc(c: ^Calculator) { c^.buffer /= 10 }},
    Button{"AC",  {},               reset},
    Button{"%",   {},               proc(c: ^Calculator) { set_op_expression(c, .MODULO) }},
    Button{"/",   {.SLASH},         proc(c: ^Calculator) { set_op_expression(c, .DIVISION) }},
    Button{"7",   {.SEVEN},         proc(c: ^Calculator) { c^.buffer = (c^.buffer * 10) + 7 }},
    Button{"8",   {.EIGHT},         proc(c: ^Calculator) { c^.buffer = (c^.buffer * 10) + 8 }},
    Button{"9",   {.NINE},          proc(c: ^Calculator) { c^.buffer = (c^.buffer * 10) + 9 }},
    Button{"*",   {.KP_MULTIPLY},   proc(c: ^Calculator) { set_op_expression(c, .MULTIPLICATION) }},
    Button{"4",   {.FOUR},          proc(c: ^Calculator) { c^.buffer = (c^.buffer * 10) + 4 }},
    Button{"5",   {.FIVE},          proc(c: ^Calculator) { c^.buffer = (c^.buffer * 10) + 5 }},
    Button{"6",   {.SIX},           proc(c: ^Calculator) { c^.buffer = (c^.buffer * 10) + 6 }},
    Button{"-",   {.MINUS},         proc(c: ^Calculator) { set_op_expression(c, .SUBTRACTION) }},
    Button{"1",   {.ONE},           proc(c: ^Calculator) { c^.buffer = (c^.buffer * 10) + 1 }},
    Button{"2",   {.TWO},           proc(c: ^Calculator) { c^.buffer = (c^.buffer * 10) + 2 }},
    Button{"3",   {.THREE},         proc(c: ^Calculator) { c^.buffer = (c^.buffer * 10) + 3 }},
    Button{"+",   {.KP_ADD},        proc(c: ^Calculator) { set_op_expression(c, .ADDITION) }},
    Button{"+/-", {},               proc(c: ^Calculator) { c^.buffer *= -1 }},
    Button{"0",   {.ZERO},          proc(c: ^Calculator) { c^.buffer = (c^.buffer * 10) + 0 }},
    Button{".",   {.PERIOD},        proc(c: ^Calculator) { /* NOP */ }},
    Button{"=",   {.EQUAL, .ENTER}, equals},
}

main :: proc () {
    rl.InitWindow(window_w, window_h, "LRCalc")
    defer rl.CloseWindow()

    // Initialize text
    // Create a buffer of font data to build a raylib image.
    pixels := make([][4]u8, mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT)
    for alpha, i in mu.default_atlas_alpha {
        pixels[i] = {0xff, 0xff, 0xff, alpha}
    }
    defer delete(pixels)

    // Create an image from the default microui text atlas. This
    // is a raylib texture image we can use to draw characters.
    image := rl.Image {
        data = raw_data(pixels),
        width = mu.DEFAULT_ATLAS_WIDTH,
        height = mu.DEFAULT_ATLAS_HEIGHT,
        mipmaps = 1,
        format  = .UNCOMPRESSED_R8G8B8A8,
    }
    atlas_texture = rl.LoadTextureFromImage(image)
    defer rl.UnloadTexture(atlas_texture)

    // Initialize microui and set text width + height
    mu.init(&mu_ctx)
    mu_ctx.text_width = mu.default_atlas_text_width
    mu_ctx.text_height = mu.default_atlas_text_height

    calculator: Calculator
    init_calculator(&calculator)

    for !rl.WindowShouldClose() {
        // Pass raylib inputs to microui
        {
            // Mouse position
            mouse_pos := [2]i32{rl.GetMouseX(), rl.GetMouseY()}
            mu.input_mouse_move(&mu_ctx, mouse_pos.x, mouse_pos.y)

            // Map raylib mouse button to microui
            @static mouse_mapper := [?]struct{
                rl_btn: rl.MouseButton,
                mu_btn: mu.Mouse,
            }{
                {.LEFT, .LEFT},
                {.RIGHT, .RIGHT},
                {.MIDDLE, .MIDDLE},
            }

            for btn in mouse_mapper {
                if rl.IsMouseButtonPressed(btn.rl_btn) {
                    mu.input_mouse_down(&mu_ctx, mouse_pos.x, mouse_pos.y, btn.mu_btn)
                } else if rl.IsMouseButtonReleased(btn.rl_btn) {
                    mu.input_mouse_up(&mu_ctx, mouse_pos.x, mouse_pos.y, btn.mu_btn)
                }
            }
        }

        // Process UI
        {
            mu.begin(&mu_ctx)
            defer mu.end(&mu_ctx)

            button_layout := []i32{48, 48, 48, -1}

            if mu.begin_window(&mu_ctx, "Calc", mu.Rect{0, 0, 256, 230}, mu.Options{.NO_RESIZE}) {
                defer mu.end_window(&mu_ctx)

                sb: strings.Builder
                strings.builder_init(&sb)
                defer strings.builder_destroy(&sb)
                format_expression(&sb, calculator.expr)

                mu.label(&mu_ctx, strings.to_string(sb))
                mu.label(&mu_ctx, fmt.tprintf("%d", calculator.buffer))
                mu.label(&mu_ctx, fmt.tprintf("%d", evaluate_expression(calculator.expr)))
                mu.layout_row(&mu_ctx, button_layout)
                for btn in CALCULATOR_BUTTONS {
                    if .SUBMIT in mu.button(&mu_ctx, btn.label) {
                        btn.action(&calculator)
                    }

                    // TODO: Only register hotkey if this is the active window
                    if len(btn.hotkeys) > 0 {
                        for key in btn.hotkeys {
                            if rl.IsKeyPressed(key) {
                                btn.action(&calculator)
                            }
                        }
                    }
                }
            }
        }

        // Rendering
        {
            rl.ClearBackground({100, 100, 100, 100})
            rl.BeginDrawing()
            defer rl.EndDrawing()

            // Draw microui elements
            command: ^mu.Command
            for variant in mu.next_command_iterator(&mu_ctx, &command) {
                #partial switch cmd in variant {
                    case ^mu.Command_Text:
                        // Get the original position of the text command
                        pos := [2]i32{cmd.pos.x, cmd.pos.y}

                        // Render each character
                        for ch in cmd.str do if ch&0xc0 != 0x80 {
                            r := int(ch) % 127

                            // Part of the atlas that contains our character
                            rect := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r]
                            src := rl.Rectangle{
                                f32(rect.x),
                                f32(rect.y),
                                f32(rect.w),
                                f32(rect.h)
                            }

                            position := rl.Vector2{f32(pos.x), f32(pos.y)}
                            rl.DrawTextureRec(atlas_texture, src, position, transmute(rl.Color)cmd.color)

                            // Advance the position to setup for the next character.
                            pos.x += rect.w
                        }
                    case ^mu.Command_Rect:
                        rl.DrawRectangle(cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h, transmute(rl.Color)cmd.color)
                    case ^mu.Command_Icon:
                        rect := mu.default_atlas[cmd.id]
                        x := cmd.rect.x + (cmd.rect.w - rect.w)/2
                        y := cmd.rect.y + (cmd.rect.h - rect.h)/2
                }
            }
        }
    }
}
