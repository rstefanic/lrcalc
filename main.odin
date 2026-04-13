package main

import "core:fmt"
import rl "vendor:raylib"
import mu "vendor:microui"

mu_ctx: mu.Context

main :: proc () {
    rl.InitWindow(1024, 768, "LRCalc")
    defer rl.CloseWindow()

    // Initialize microui and set text width + height
    mu.init(&mu_ctx)
    mu_ctx.text_width = mu.default_atlas_text_width
    mu_ctx.text_height = mu.default_atlas_text_height

    for !rl.WindowShouldClose() {
        // Process UI
        {
            mu.begin(&mu_ctx)
            defer mu.end(&mu_ctx)

            if mu.begin_window(&mu_ctx, "L Calc", mu.Rect{40, 40, 300, 450}) {
                defer mu.end_window(&mu_ctx)

                mu.layout_row(&mu_ctx, {30, 30})
                mu.button(&mu_ctx, "")
                mu.button(&mu_ctx, "")
                mu.button(&mu_ctx, "")
                mu.button(&mu_ctx, "")
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
