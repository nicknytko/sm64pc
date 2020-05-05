#include <stdbool.h>
#include <ultra64.h>
#include <string.h>

#include "controller_api.h"

#ifdef TARGET_WEB
#include "controller_emscripten_keyboard.h"
#endif

#include "../configfile.h"

static int keyboard_buttons_down;
static int keyboard_mapping[13][2];
static pc_controls_t kbm_pc_controls;

static int keyboard_map_scancode(int scancode) {
    int ret = 0;
    for (size_t i = 0; i < sizeof(keyboard_mapping) / sizeof(keyboard_mapping[0]); i++) {
        if (keyboard_mapping[i][0] == scancode) {
            ret |= keyboard_mapping[i][1];
        }
    }
    return ret;
}

bool keyboard_on_key_down(int scancode) {
    int mapped = keyboard_map_scancode(scancode);
    keyboard_buttons_down |= mapped;
    
    if (scancode == configKeyJump) {
        kbm_pc_controls.jump = 1;
        kbm_pc_controls.jump_pressed = 1;
        return 1;
    }
    if (scancode == configKeyCrouch) {
        kbm_pc_controls.crouch = 1;
        kbm_pc_controls.crouch_pressed = 1;
        return 1;
    }
    if (scancode == configKeyPunch) {
        kbm_pc_controls.punch = 1;
        kbm_pc_controls.punch_pressed = 1;
        return 1;
    }
    if (scancode == configKeyMenu) {
        kbm_pc_controls.menu = 1;
        kbm_pc_controls.menu_pressed = 1;
        return 1;
    }
    
    return mapped != 0;
}

bool keyboard_on_key_up(int scancode) {
    int mapped = keyboard_map_scancode(scancode);
    keyboard_buttons_down &= ~mapped;
    
    if (scancode == configKeyJump) {
        kbm_pc_controls.jump = 0;
        kbm_pc_controls.jump_pressed = 0;
        return 1;
    }
    if (scancode == configKeyCrouch) {
        kbm_pc_controls.crouch = 0;
        kbm_pc_controls.crouch_pressed = 0;
        return 1;
    }
    if (scancode == configKeyPunch) {
        kbm_pc_controls.punch = 0;
        kbm_pc_controls.punch_pressed = 0;
        return 1;
    }
    if (scancode == configKeyMenu) {
        kbm_pc_controls.menu = 0;
        kbm_pc_controls.menu_pressed = 0;
        return 1;
    }
    
    return mapped != 0;
}

bool mouse_move(s32 xrel, s32 yrel) {
    kbm_pc_controls.mouse_delta_x = xrel;
    kbm_pc_controls.mouse_delta_y = yrel;
}

bool mouse_click(int index, bool val) {
    if (index == 0){
        kbm_pc_controls.mouse_left = val;
        kbm_pc_controls.mouse_left_pressed = val;
    }
    if (index == 1){
        kbm_pc_controls.mouse_right = val;
        kbm_pc_controls.mouse_right_pressed = val;
    }    
}

bool mouse_wheel(bool up, bool down) {
    kbm_pc_controls.mouse_wheel_up = up;
    kbm_pc_controls.mouse_wheel_down = down;
}

void keyboard_on_all_keys_up(void) {
    keyboard_buttons_down = 0;
}

static void set_keyboard_mapping(int index, int mask, int scancode) {
    keyboard_mapping[index][0] = scancode;
    keyboard_mapping[index][1] = mask;
}

static void keyboard_init(void) {
    int i = 0;

    set_keyboard_mapping(i++, 0x80000,      configKeyStickUp);
    set_keyboard_mapping(i++, 0x10000,      configKeyStickLeft);
    set_keyboard_mapping(i++, 0x40000,      configKeyStickDown);
    set_keyboard_mapping(i++, 0x20000,      configKeyStickRight);
    set_keyboard_mapping(i++, A_BUTTON,     configKeyA);
    set_keyboard_mapping(i++, B_BUTTON,     configKeyB);
    set_keyboard_mapping(i++, Z_TRIG,       configKeyZ);
    set_keyboard_mapping(i++, U_CBUTTONS,   configKeyCUp);
    set_keyboard_mapping(i++, L_CBUTTONS,   configKeyCLeft);
    set_keyboard_mapping(i++, D_CBUTTONS,   configKeyCDown);
    set_keyboard_mapping(i++, R_CBUTTONS,   configKeyCRight);
    set_keyboard_mapping(i++, R_TRIG,       configKeyR);
    set_keyboard_mapping(i++, START_BUTTON, configKeyStart);

#ifdef TARGET_WEB
    controller_emscripten_keyboard_init();
#endif
}

static void keyboard_read(OSContPad *pad) {
    pad->button |= keyboard_buttons_down;
    if ((keyboard_buttons_down & 0x30000) == 0x10000) {
        pad->stick_x = -128;
    }
    if ((keyboard_buttons_down & 0x30000) == 0x20000) {
        pad->stick_x = 127;
    }
    if ((keyboard_buttons_down & 0xc0000) == 0x40000) {
        pad->stick_y = -128;
    }
    if ((keyboard_buttons_down & 0xc0000) == 0x80000) {
        pad->stick_y = 127;
    }

    memcpy(&pad->pc_controls, &kbm_pc_controls, sizeof(pc_controls_t));
    kbm_pc_controls.jump_pressed = 0;
    kbm_pc_controls.crouch_pressed = 0;
    kbm_pc_controls.punch_pressed = 0;
    kbm_pc_controls.menu_pressed = 0;
    kbm_pc_controls.mouse_delta_x = 0;
    kbm_pc_controls.mouse_delta_y = 0;
    kbm_pc_controls.mouse_left_pressed = 0;
    kbm_pc_controls.mouse_right_pressed = 0;
    kbm_pc_controls.mouse_wheel_up = false;
    kbm_pc_controls.mouse_wheel_down = false;
}

struct ControllerAPI controller_keyboard = {
    keyboard_init,
    keyboard_read
};
