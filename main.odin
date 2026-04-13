package main

import "core:fmt"
import rl "vendor:raylib"
import mu "vendor:microui"

mu_ctx: mu.Context
atlas_texture: rl.Texture2D

main :: proc () {
    rl.InitWindow(1024, 768, "LRCalc")
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
                    case ^mu.Command_Text:
                        // Get the original position of the text command
                        pos := [2]i32{cmd.pos.x, cmd.pos.y}

                        // Render each character
                        for ch in cmd.str do if ch&0xc0 != 0x80 {
                            r := int(ch) % 127

                            // Get the character from the default atlas
                            rect := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r]
                            src := rl.Rectangle{
                                f32(rect.x),
                                f32(rect.y),
                                f32(rect.w),
                                f32(rect.h)
                            }

                            // Draw the character
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
