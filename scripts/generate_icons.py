#!/usr/bin/env python3
"""
生成死了么 App 图标
生成所有 iOS 需要的图标尺寸
"""

from PIL import Image, ImageDraw, ImageFont
import os
import json

# 图标尺寸配置（iOS 15+ 只需要 1024x1024，但为了兼容性，我们生成所有尺寸）
ICON_SIZES = [
    (20, 20, "20x20"),
    (29, 29, "29x29"),
    (40, 40, "40x40"),
    (60, 60, "60x60"),
    (76, 76, "76x76"),
    (83.5, 83.5, "83.5x83.5"),
    (1024, 1024, "1024x1024"),
]

# 主题色（绿色系，与应用保持一致）
PRIMARY_COLOR = (51, 179, 77)  # RGB: 0x33B34D
BACKGROUND_COLOR = (230, 243, 230)  # 浅绿色背景
WHITE = (255, 255, 255)
DARK_GRAY = (100, 100, 100)

def create_ghost_icon(size):
    """创建幽灵图标"""
    # 创建透明背景
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 计算缩放比例
    scale = size / 1024.0
    center_x, center_y = size / 2, size / 2
    
    # 绘制幽灵身体（上半部分圆形）
    ghost_radius = int(size * 0.25)
    wave_radius = int(size * 0.08)
    
    # 计算幽灵的总高度，然后居中放置
    # 上半圆直径 + 下半波浪直径
    total_height = ghost_radius * 2 + wave_radius * 2
    # 幽灵的顶部位置，使整个幽灵在垂直方向居中
    ghost_top = center_y - total_height / 2 + ghost_radius
    
    # 上半部分圆形
    draw.ellipse(
        [center_x - ghost_radius, ghost_top - ghost_radius,
         center_x + ghost_radius, ghost_top + ghost_radius],
        fill=PRIMARY_COLOR + (255,)
    )
    
    # 下半部分波浪（三个半圆）
    wave_y = ghost_top + ghost_radius
    
    for i, offset in enumerate([-wave_radius * 1.5, 0, wave_radius * 1.5]):
        wave_x = center_x + offset
        draw.ellipse(
            [wave_x - wave_radius, wave_y - wave_radius,
             wave_x + wave_radius, wave_y + wave_radius],
            fill=PRIMARY_COLOR + (255,)
        )
    
    # 绘制两个眼睛
    eye_size = max(3, int(size * 0.04))
    eye_y = ghost_top - int(size * 0.05)
    eye_spacing = int(size * 0.08)
    
    draw.ellipse(
        [center_x - eye_spacing - eye_size, eye_y - eye_size,
         center_x - eye_spacing + eye_size, eye_y + eye_size],
        fill=WHITE + (255,)
    )
    draw.ellipse(
        [center_x + eye_spacing - eye_size, eye_y - eye_size,
         center_x + eye_spacing + eye_size, eye_y + eye_size],
        fill=WHITE + (255,)
    )
    
    # 绘制嘴巴（弧形）
    mouth_y = ghost_top + int(size * 0.05)
    mouth_width = int(size * 0.1)
    mouth_height = int(size * 0.06)
    
    # 使用 arc 绘制嘴巴
    draw.arc(
        [center_x - mouth_width, mouth_y - mouth_height,
         center_x + mouth_width, mouth_y + mouth_height],
        start=0,
        end=180,
        fill=WHITE + (255,),
        width=max(2, int(size * 0.015))
    )
    
    return img

def create_dark_icon(size):
    """创建深色模式图标"""
    img = create_ghost_icon(size)
    # 深色模式：反转颜色或使用深色背景
    # 这里我们保持相同的设计，但可以调整颜色
    return img

def create_tinted_icon(size):
    """创建 tinted 模式图标（单色）"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    scale = size / 1024.0
    center_x, center_y = size / 2, size / 2
    
    # 绘制简化的幽灵图标（单色）
    ghost_radius = int(size * 0.3)
    wave_radius = int(size * 0.08)
    
    # 计算幽灵的总高度，然后居中放置
    total_height = ghost_radius * 2 + wave_radius * 2
    # 幽灵的顶部位置，使整个幽灵在垂直方向居中
    ghost_top = center_y - total_height / 2 + ghost_radius
    
    # 上半部分圆形
    draw.ellipse(
        [center_x - ghost_radius, ghost_top - ghost_radius,
         center_x + ghost_radius, ghost_top + ghost_radius],
        fill=DARK_GRAY + (255,)
    )
    
    # 下半部分波浪
    wave_y = ghost_top + ghost_radius
    
    for i, offset in enumerate([-wave_radius * 1.5, 0, wave_radius * 1.5]):
        wave_x = center_x + offset
        draw.ellipse(
            [wave_x - wave_radius, wave_y - wave_radius,
             wave_x + wave_radius, wave_y + wave_radius],
            fill=DARK_GRAY + (255,)
        )
    
    # 眼睛
    eye_size = max(3, int(size * 0.04))
    eye_y = ghost_top - int(size * 0.05)
    eye_spacing = int(size * 0.08)
    
    draw.ellipse(
        [center_x - eye_spacing - eye_size, eye_y - eye_size,
         center_x - eye_spacing + eye_size, eye_y + eye_size],
        fill=WHITE + (255,)
    )
    draw.ellipse(
        [center_x + eye_spacing - eye_size, eye_y - eye_size,
         center_x + eye_spacing + eye_size, eye_y + eye_size],
        fill=WHITE + (255,)
    )
    
    return img

def main():
    """生成所有图标"""
    __dir__ = os.path.dirname(os.path.abspath(__file__))
    output_dir = os.path.join(__dir__, "../DeadOrNot/Assets.xcassets/AppIcon.appiconset")
    os.makedirs(output_dir, exist_ok=True)
    
    # 生成标准图标（1024x1024）
    print("生成 1024x1024 图标...")
    icon_1024 = create_ghost_icon(1024)
    icon_1024.save(os.path.join(output_dir, "AppIcon-1024.png"), "PNG")
    
    # 生成深色模式图标
    print("生成深色模式图标...")
    icon_dark = create_dark_icon(1024)
    icon_dark.save(os.path.join(output_dir, "AppIcon-1024-dark.png"), "PNG")
    
    # 生成 tinted 模式图标
    print("生成 tinted 模式图标...")
    icon_tinted = create_tinted_icon(1024)
    icon_tinted.save(os.path.join(output_dir, "AppIcon-1024-tinted.png"), "PNG")
    
    # 更新 Contents.json
    contents = {
        "images": [
            {
                "filename": "AppIcon-1024.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024"
            },
            {
                "appearances": [
                    {
                        "appearance": "luminosity",
                        "value": "dark"
                    }
                ],
                "filename": "AppIcon-1024-dark.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024"
            },
            {
                "appearances": [
                    {
                        "appearance": "luminosity",
                        "value": "tinted"
                    }
                ],
                "filename": "AppIcon-1024-tinted.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024"
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        }
    }
    
    with open(os.path.join(output_dir, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    
    print(f"✅ 图标生成完成！保存在 {output_dir}")
    print("📱 已生成以下图标：")
    print("   - AppIcon-1024.png (标准)")
    print("   - AppIcon-1024-dark.png (深色模式)")
    print("   - AppIcon-1024-tinted.png (tinted 模式)")

if __name__ == "__main__":
    main()
