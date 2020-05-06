#ifndef CONTROLLER_KBM_H
#define CONTROLLER_KBM_H

#include <stdbool.h>
#include "controller_api.h"

#ifdef __cplusplus
extern "C" {
#endif
bool keyboard_on_key_down(int scancode);
bool keyboard_on_key_up(int scancode);
void keyboard_on_all_keys_up(void);
bool mouse_move(s32 xrel, s32 yrel);
bool mouse_click(int index, bool val);
bool mouse_wheel(bool up, bool down);
#ifdef __cplusplus
}
#endif

extern struct ControllerAPI controller_kbm;

#endif
