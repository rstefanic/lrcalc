package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"
import mu "vendor:microui"

mu_ctx: mu.Context
atlas_texture: rl.Texture2D

Button :: struct {
    label: string,
    action: proc(calc: ^Calculator)
}

CALCULATOR_BUTTONS :: []Button{
    Button{"<-", proc(c: ^Calculator) { c^.buffer /= 10 }},
    Button{"AC", proc(c: ^Calculator) { c^.result = 0; c^.buffer = 0}},
    Button{"%", proc(c: ^Calculator) {}},
    Button{"/", proc(c: ^Calculator) { c^.op = .DIVISION; c^.result = c.buffer; c^.buffer = 0 }},
    Button{"7", proc(c: ^Calculator) { c^.buffer = (c^.buffer * 10) + 7 }},
    Button{"8", proc(c: ^Calculator) { c^.buffer = (c^.buffer * 10) + 8 }},
    Button{"9", proc(c: ^Calculator) { c^.buffer = (c^.buffer * 10) + 9 }},
    Button{"x", proc(c: ^Calculator) { c^.op = .MULTIPLICATION; c^.result = c.buffer; c^.buffer = 0 }},
    Button{"4", proc(c: ^Calculator) { c^.buffer = (c^.buffer * 10) + 4 }},
    Button{"5", proc(c: ^Calculator) { c^.buffer = (c^.buffer * 10) + 5 }},
    Button{"6", proc(c: ^Calculator) { c^.buffer = (c^.buffer * 10) + 6 }},
    Button{"-", proc(c: ^Calculator) { c^.op = .SUBTRACTION; c^.result = c.buffer; c^.buffer = 0 }},
    Button{"1", proc(c: ^Calculator) { c^.buffer = (c^.buffer * 10) + 1 }},
    Button{"2", proc(c: ^Calculator) { c^.buffer = (c^.buffer * 10) + 2 }},
    Button{"3", proc(c: ^Calculator) { c^.buffer = (c^.buffer * 10) + 3 }},
    Button{"+", proc(c: ^Calculator) { c^.op = .ADDITION; c^.result = c.buffer; c^.buffer = 0 }},
    Button{"+/-", proc(c: ^Calculator) { c^.buffer *= -1 }},
    Button{"0", proc(c: ^Calculator) { c^.buffer = (c^.buffer * 10) + 0 }},
    Button{".", proc(c: ^Calculator) {}},
    Button{"=", equals},
}

main :: proc () {
    rl.InitWindow(512, 412, "LRCalc")
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
    mu_ctx.style.size = 48

    calculator := Calculator{0, 0, .NONE}

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

            button_layout := []i32{110, 110, 110, -1}

            if mu.begin_window(&mu_ctx, "Calc", mu.Rect{0, 0, 512, 412}, mu.Options{.NO_RESIZE}) {
                defer mu.end_window(&mu_ctx)
                if calculator.op == .NONE && calculator.buffer == 0 {
                    mu.label(&mu_ctx, fmt.tprintf("%d", calculator.result))
                } else {
                    mu.label(&mu_ctx, fmt.tprintf("%d", calculator.buffer))
                }

                mu.layout_row(&mu_ctx, button_layout)
                for btn in CALCULATOR_BUTTONS {
                    if .SUBMIT in mu.button(&mu_ctx, btn.label) {
                        btn.action(&calculator)
                    }
                }
            }
        }

        // Rendering
        {
            rl.ClearBackground({255, 255, 255, 255})
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
