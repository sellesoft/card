local ffi = require "ffi";
ffi.cdef [[
// Style property
// NOTE: Used when exporting style as code for convenience
typedef struct GuiStyleProp {
    unsigned short controlId;   // Control identifier
    unsigned short propertyId;  // Property identifier
    int propertyValue;          // Property value
} GuiStyleProp;

/*
// Controls text style -NOT USED-
// NOTE: Text style is defined by control
typedef struct GuiTextStyle {
    unsigned int size;
    int charSpacing;
    int lineSpacing;
    int alignmentH;
    int alignmentV;
    int padding;
} GuiTextStyle;
*/

// Gui control state
typedef enum {
    STATE_NORMAL = 0,
    STATE_FOCUSED,
    STATE_PRESSED,
    STATE_DISABLED
} GuiState;

// Gui control text alignment
typedef enum {
    TEXT_ALIGN_LEFT = 0,
    TEXT_ALIGN_CENTER,
    TEXT_ALIGN_RIGHT
} GuiTextAlignment;

// Gui control text alignment vertical
// NOTE: Text vertical position inside the text bounds
typedef enum {
    TEXT_ALIGN_TOP = 0,
    TEXT_ALIGN_MIDDLE,
    TEXT_ALIGN_BOTTOM
} GuiTextAlignmentVertical;

// Gui control text wrap mode
// NOTE: Useful for multiline text
typedef enum {
    TEXT_WRAP_NONE = 0,
    TEXT_WRAP_CHAR,
    TEXT_WRAP_WORD
} GuiTextWrapMode;

// Gui controls
typedef enum {
    // Default -> populates to all controls when set
    DEFAULT = 0,
    
    // Basic controls
    LABEL,          // Used also for: LABELBUTTON
    BUTTON,
    TOGGLE,         // Used also for: TOGGLEGROUP
    SLIDER,         // Used also for: SLIDERBAR, TOGGLESLIDER
    PROGRESSBAR,
    CHECKBOX,
    COMBOBOX,
    DROPDOWNBOX,
    TEXTBOX,        // Used also for: TEXTBOXMULTI
    VALUEBOX,
    SPINNER,        // Uses: BUTTON, VALUEBOX
    LISTVIEW,
    COLORPICKER,
    SCROLLBAR,
    STATUSBAR
} GuiControl;

// Gui base properties for every control
// NOTE: RAYGUI_MAX_PROPS_BASE properties (by default 16 properties)
typedef enum {
    BORDER_COLOR_NORMAL = 0,    // Control border color in STATE_NORMAL
    BASE_COLOR_NORMAL,          // Control base color in STATE_NORMAL
    TEXT_COLOR_NORMAL,          // Control text color in STATE_NORMAL
    BORDER_COLOR_FOCUSED,       // Control border color in STATE_FOCUSED
    BASE_COLOR_FOCUSED,         // Control base color in STATE_FOCUSED
    TEXT_COLOR_FOCUSED,         // Control text color in STATE_FOCUSED
    BORDER_COLOR_PRESSED,       // Control border color in STATE_PRESSED
    BASE_COLOR_PRESSED,         // Control base color in STATE_PRESSED
    TEXT_COLOR_PRESSED,         // Control text color in STATE_PRESSED
    BORDER_COLOR_DISABLED,      // Control border color in STATE_DISABLED
    BASE_COLOR_DISABLED,        // Control base color in STATE_DISABLED
    TEXT_COLOR_DISABLED,        // Control text color in STATE_DISABLED
    BORDER_WIDTH,               // Control border size, 0 for no border
    //TEXT_SIZE,                  // Control text size (glyphs max height) -> GLOBAL for all controls
    //TEXT_SPACING,               // Control text spacing between glyphs -> GLOBAL for all controls
    //TEXT_LINE_SPACING           // Control text spacing between lines -> GLOBAL for all controls
    TEXT_PADDING,               // Control text padding, not considering border
    TEXT_ALIGNMENT,             // Control text horizontal alignment inside control text bound (after border and padding)
    //TEXT_WRAP_MODE              // Control text wrap-mode inside text bounds -> GLOBAL for all controls
} GuiControlProperty;

// TODO: Which text styling properties should be global or per-control?
// At this moment TEXT_PADDING and TEXT_ALIGNMENT is configured and saved per control while
// TEXT_SIZE, TEXT_SPACING, TEXT_LINE_SPACING, TEXT_ALIGNMENT_VERTICAL, TEXT_WRAP_MODE are global and
// should be configured by user as needed while defining the UI layout


// Gui extended properties depend on control
// NOTE: RAYGUI_MAX_PROPS_EXTENDED properties (by default, max 8 properties)
//----------------------------------------------------------------------------------
// DEFAULT extended properties
// NOTE: Those properties are common to all controls or global
// WARNING: We only have 8 slots for those properties by default!!! -> New global control: TEXT?
typedef enum {
    TEXT_SIZE = 16,             // Text size (glyphs max height)
    TEXT_SPACING,               // Text spacing between glyphs
    LINE_COLOR,                 // Line control color
    BACKGROUND_COLOR,           // Background color
    TEXT_LINE_SPACING,          // Text spacing between lines
    TEXT_ALIGNMENT_VERTICAL,    // Text vertical alignment inside text bounds (after border and padding)
    TEXT_WRAP_MODE              // Text wrap-mode inside text bounds
    //TEXT_DECORATION             // Text decoration: 0-None, 1-Underline, 2-Line-through, 3-Overline
    //TEXT_DECORATION_THICK       // Text decoration line thikness
} GuiDefaultProperty;

// Other possible text properties:
// TEXT_WEIGHT                  // Normal, Italic, Bold -> Requires specific font change
// TEXT_INDENT	                // Text indentation -> Now using TEXT_PADDING...

// Label
//typedef enum { } GuiLabelProperty;

// Button/Spinner
//typedef enum { } GuiButtonProperty;

// Toggle/ToggleGroup
typedef enum {
    GROUP_PADDING = 16,         // ToggleGroup separation between toggles
} GuiToggleProperty;

// Slider/SliderBar
typedef enum {
    SLIDER_WIDTH = 16,          // Slider size of internal bar
    SLIDER_PADDING              // Slider/SliderBar internal bar padding
} GuiSliderProperty;

// ProgressBar
typedef enum {
    PROGRESS_PADDING = 16,      // ProgressBar internal padding
} GuiProgressBarProperty;

// ScrollBar
typedef enum {
    ARROWS_SIZE = 16,           // ScrollBar arrows size
    ARROWS_VISIBLE,             // ScrollBar arrows visible
    SCROLL_SLIDER_PADDING,      // ScrollBar slider internal padding
    SCROLL_SLIDER_SIZE,         // ScrollBar slider size
    SCROLL_PADDING,             // ScrollBar scroll padding from arrows
    SCROLL_SPEED,               // ScrollBar scrolling speed
} GuiScrollBarProperty;

// CheckBox
typedef enum {
    CHECK_PADDING = 16          // CheckBox internal check padding
} GuiCheckBoxProperty;

// ComboBox
typedef enum {
    COMBO_BUTTON_WIDTH = 16,    // ComboBox right button width
    COMBO_BUTTON_SPACING        // ComboBox button separation
} GuiComboBoxProperty;

// DropdownBox
typedef enum {
    ARROW_PADDING = 16,         // DropdownBox arrow separation from border and items
    DROPDOWN_ITEMS_SPACING      // DropdownBox items separation
} GuiDropdownBoxProperty;

// TextBox/TextBoxMulti/ValueBox/Spinner
typedef enum {
    TEXT_READONLY = 16,         // TextBox in read-only mode: 0-text editable, 1-text no-editable
} GuiTextBoxProperty;

// Spinner
typedef enum {
    SPIN_BUTTON_WIDTH = 16,     // Spinner left/right buttons width
    SPIN_BUTTON_SPACING,        // Spinner buttons separation
} GuiSpinnerProperty;

// ListView
typedef enum {
    LIST_ITEMS_HEIGHT = 16,     // ListView items height
    LIST_ITEMS_SPACING,         // ListView items separation
    SCROLLBAR_WIDTH,            // ListView scrollbar size (usually width)
    SCROLLBAR_SIDE,             // ListView scrollbar side (0-SCROLLBAR_LEFT_SIDE, 1-SCROLLBAR_RIGHT_SIDE)
} GuiListViewProperty;

// ColorPicker
typedef enum {
    COLOR_SELECTOR_SIZE = 16,
    HUEBAR_WIDTH,               // ColorPicker right hue bar width
    HUEBAR_PADDING,             // ColorPicker right hue bar separation from panel
    HUEBAR_SELECTOR_HEIGHT,     // ColorPicker right hue bar selector height
    HUEBAR_SELECTOR_OVERFLOW    // ColorPicker right hue bar selector overflow
} GuiColorPickerProperty;

//----------------------------------------------------------------------------------
// Module Functions Declaration
//----------------------------------------------------------------------------------

// Global gui state control functions
void GuiEnable(void);                                 // Enable gui controls (global state)
void GuiDisable(void);                                // Disable gui controls (global state)
void GuiLock(void);                                   // Lock gui controls (global state)
void GuiUnlock(void);                                 // Unlock gui controls (global state)
bool GuiIsLocked(void);                               // Check if gui is locked (global state)
void GuiSetAlpha(float alpha);                        // Set gui controls alpha (global state), alpha goes from 0.0f to 1.0f
void GuiSetState(int state);                          // Set gui state (global state)
int GuiGetState(void);                                // Get gui state (global state)

// Font set/get functions
void GuiSetFont(Font font);                           // Set gui custom font (global state)
Font GuiGetFont(void);                                // Get gui custom font (global state)

// Style set/get functions
void GuiSetStyle(int control, int property, int value); // Set one style property
int GuiGetStyle(int control, int property);           // Get one style property

// Styles loading functions
void GuiLoadStyle(const char *fileName);              // Load style file over global style variable (.rgs)
void GuiLoadStyleDefault(void);                       // Load style default over global style

// Tooltips management functions
void GuiEnableTooltip(void);                          // Enable gui tooltips (global state)
void GuiDisableTooltip(void);                         // Disable gui tooltips (global state)
void GuiSetTooltip(const char *tooltip);              // Set tooltip string

// Icons functionality
const char *GuiIconText(int iconId, const char *text); // Get text with icon id prepended (if supported)
void GuiSetIconScale(int scale);                      // Set default icon drawing size
unsigned int *GuiGetIcons(void);                      // Get raygui icons data pointer
char **GuiLoadIcons(const char *fileName, bool loadIconsName); // Load raygui icons file (.rgi) into internal icons data
void GuiDrawIcon(int iconId, int posX, int posY, int pixelSize, Color color); // Draw icon using pixel size at specified position


// Controls
//----------------------------------------------------------------------------------------------------------
// Container/separator controls, useful for controls organization
int GuiWindowBox(Rectangle bounds, const char *title);                                       // Window Box control, shows a window that can be closed
int GuiGroupBox(Rectangle bounds, const char *text);                                         // Group Box control with text name
int GuiLine(Rectangle bounds, const char *text);                                             // Line separator control, could contain text
int GuiPanel(Rectangle bounds, const char *text);                                            // Panel control, useful to group controls
int GuiTabBar(Rectangle bounds, const char **text, int count, int *active);                  // Tab Bar control, returns TAB to be closed or -1
int GuiScrollPanel(Rectangle bounds, const char *text, Rectangle content, Vector2 *scroll, Rectangle *view); // Scroll Panel control

// Basic controls set
int GuiLabel(Rectangle bounds, const char *text);                                            // Label control, shows text
int GuiButton(Rectangle bounds, const char *text);                                           // Button control, returns true when clicked
int GuiLabelButton(Rectangle bounds, const char *text);                                      // Label button control, show true when clicked
int GuiToggle(Rectangle bounds, const char *text, bool *active);                             // Toggle Button control, returns true when active
int GuiToggleGroup(Rectangle bounds, const char *text, int *active);                         // Toggle Group control, returns active toggle index
int GuiToggleSlider(Rectangle bounds, const char *text, int *active);                        // Toggle Slider control, returns true when clicked
int GuiCheckBox(Rectangle bounds, const char *text, bool *checked);                          // Check Box control, returns true when active
int GuiComboBox(Rectangle bounds, const char *text, int *active);                            // Combo Box control, returns selected item index

int GuiDropdownBox(Rectangle bounds, const char *text, int *active, bool editMode);          // Dropdown Box control, returns selected item
int GuiSpinner(Rectangle bounds, const char *text, int *value, int minValue, int maxValue, bool editMode); // Spinner control, returns selected value
int GuiValueBox(Rectangle bounds, const char *text, int *value, int minValue, int maxValue, bool editMode); // Value Box control, updates input text with numbers
int GuiTextBox(Rectangle bounds, char *text, int textSize, bool editMode);                   // Text Box control, updates input text

int GuiSlider(Rectangle bounds, const char *textLeft, const char *textRight, float *value, float minValue, float maxValue); // Slider control, returns selected value
int GuiSliderBar(Rectangle bounds, const char *textLeft, const char *textRight, float *value, float minValue, float maxValue); // Slider Bar control, returns selected value
int GuiProgressBar(Rectangle bounds, const char *textLeft, const char *textRight, float *value, float minValue, float maxValue); // Progress Bar control, shows current progress value
int GuiStatusBar(Rectangle bounds, const char *text);                                        // Status Bar control, shows info text
int GuiDummyRec(Rectangle bounds, const char *text);                                         // Dummy control for placeholders
int GuiGrid(Rectangle bounds, const char *text, float spacing, int subdivs, Vector2 *mouseCell); // Grid control, returns mouse cell position

// Advance controls set
int GuiListView(Rectangle bounds, const char *text, int *scrollIndex, int *active);          // List View control, returns selected list item index
int GuiListViewEx(Rectangle bounds, const char **text, int count, int *scrollIndex, int *active, int *focus); // List View with extended parameters
int GuiMessageBox(Rectangle bounds, const char *title, const char *message, const char *buttons); // Message Box control, displays a message
int GuiTextInputBox(Rectangle bounds, const char *title, const char *message, const char *buttons, char *text, int textMaxSize, bool *secretViewActive); // Text Input Box control, ask for text, supports secret
int GuiColorPicker(Rectangle bounds, const char *text, Color *color);                        // Color Picker control (multiple color controls)
int GuiColorPanel(Rectangle bounds, const char *text, Color *color);                         // Color Panel control
int GuiColorBarAlpha(Rectangle bounds, const char *text, float *alpha);                      // Color Bar Alpha control
int GuiColorBarHue(Rectangle bounds, const char *text, float *value);                        // Color Bar Hue control
int GuiColorPickerHSV(Rectangle bounds, const char *text, Vector3 *colorHsv);                // Color Picker control that avoids conversion to RGB on each call (multiple color controls)
int GuiColorPanelHSV(Rectangle bounds, const char *text, Vector3 *colorHsv);                 // Color Panel control that returns HSV color value, used by GuiColorPickerHSV()
//----------------------------------------------------------------------------------------------------------

//----------------------------------------------------------------------------------
// Icons enumeration
//----------------------------------------------------------------------------------
typedef enum {
    ICON_NONE                     = 0,
    ICON_FOLDER_FILE_OPEN         = 1,
    ICON_FILE_SAVE_CLASSIC        = 2,
    ICON_FOLDER_OPEN              = 3,
    ICON_FOLDER_SAVE              = 4,
    ICON_FILE_OPEN                = 5,
    ICON_FILE_SAVE                = 6,
    ICON_FILE_EXPORT              = 7,
    ICON_FILE_ADD                 = 8,
    ICON_FILE_DELETE              = 9,
    ICON_FILETYPE_TEXT            = 10,
    ICON_FILETYPE_AUDIO           = 11,
    ICON_FILETYPE_IMAGE           = 12,
    ICON_FILETYPE_PLAY            = 13,
    ICON_FILETYPE_VIDEO           = 14,
    ICON_FILETYPE_INFO            = 15,
    ICON_FILE_COPY                = 16,
    ICON_FILE_CUT                 = 17,
    ICON_FILE_PASTE               = 18,
    ICON_CURSOR_HAND              = 19,
    ICON_CURSOR_POINTER           = 20,
    ICON_CURSOR_CLASSIC           = 21,
    ICON_PENCIL                   = 22,
    ICON_PENCIL_BIG               = 23,
    ICON_BRUSH_CLASSIC            = 24,
    ICON_BRUSH_PAINTER            = 25,
    ICON_WATER_DROP               = 26,
    ICON_COLOR_PICKER             = 27,
    ICON_RUBBER                   = 28,
    ICON_COLOR_BUCKET             = 29,
    ICON_TEXT_T                   = 30,
    ICON_TEXT_A                   = 31,
    ICON_SCALE                    = 32,
    ICON_RESIZE                   = 33,
    ICON_FILTER_POINT             = 34,
    ICON_FILTER_BILINEAR          = 35,
    ICON_CROP                     = 36,
    ICON_CROP_ALPHA               = 37,
    ICON_SQUARE_TOGGLE            = 38,
    ICON_SYMMETRY                 = 39,
    ICON_SYMMETRY_HORIZONTAL      = 40,
    ICON_SYMMETRY_VERTICAL        = 41,
    ICON_LENS                     = 42,
    ICON_LENS_BIG                 = 43,
    ICON_EYE_ON                   = 44,
    ICON_EYE_OFF                  = 45,
    ICON_FILTER_TOP               = 46,
    ICON_FILTER                   = 47,
    ICON_TARGET_POINT             = 48,
    ICON_TARGET_SMALL             = 49,
    ICON_TARGET_BIG               = 50,
    ICON_TARGET_MOVE              = 51,
    ICON_CURSOR_MOVE              = 52,
    ICON_CURSOR_SCALE             = 53,
    ICON_CURSOR_SCALE_RIGHT       = 54,
    ICON_CURSOR_SCALE_LEFT        = 55,
    ICON_UNDO                     = 56,
    ICON_REDO                     = 57,
    ICON_REREDO                   = 58,
    ICON_MUTATE                   = 59,
    ICON_ROTATE                   = 60,
    ICON_REPEAT                   = 61,
    ICON_SHUFFLE                  = 62,
    ICON_EMPTYBOX                 = 63,
    ICON_TARGET                   = 64,
    ICON_TARGET_SMALL_FILL        = 65,
    ICON_TARGET_BIG_FILL          = 66,
    ICON_TARGET_MOVE_FILL         = 67,
    ICON_CURSOR_MOVE_FILL         = 68,
    ICON_CURSOR_SCALE_FILL        = 69,
    ICON_CURSOR_SCALE_RIGHT_FILL  = 70,
    ICON_CURSOR_SCALE_LEFT_FILL   = 71,
    ICON_UNDO_FILL                = 72,
    ICON_REDO_FILL                = 73,
    ICON_REREDO_FILL              = 74,
    ICON_MUTATE_FILL              = 75,
    ICON_ROTATE_FILL              = 76,
    ICON_REPEAT_FILL              = 77,
    ICON_SHUFFLE_FILL             = 78,
    ICON_EMPTYBOX_SMALL           = 79,
    ICON_BOX                      = 80,
    ICON_BOX_TOP                  = 81,
    ICON_BOX_TOP_RIGHT            = 82,
    ICON_BOX_RIGHT                = 83,
    ICON_BOX_BOTTOM_RIGHT         = 84,
    ICON_BOX_BOTTOM               = 85,
    ICON_BOX_BOTTOM_LEFT          = 86,
    ICON_BOX_LEFT                 = 87,
    ICON_BOX_TOP_LEFT             = 88,
    ICON_BOX_CENTER               = 89,
    ICON_BOX_CIRCLE_MASK          = 90,
    ICON_POT                      = 91,
    ICON_ALPHA_MULTIPLY           = 92,
    ICON_ALPHA_CLEAR              = 93,
    ICON_DITHERING                = 94,
    ICON_MIPMAPS                  = 95,
    ICON_BOX_GRID                 = 96,
    ICON_GRID                     = 97,
    ICON_BOX_CORNERS_SMALL        = 98,
    ICON_BOX_CORNERS_BIG          = 99,
    ICON_FOUR_BOXES               = 100,
    ICON_GRID_FILL                = 101,
    ICON_BOX_MULTISIZE            = 102,
    ICON_ZOOM_SMALL               = 103,
    ICON_ZOOM_MEDIUM              = 104,
    ICON_ZOOM_BIG                 = 105,
    ICON_ZOOM_ALL                 = 106,
    ICON_ZOOM_CENTER              = 107,
    ICON_BOX_DOTS_SMALL           = 108,
    ICON_BOX_DOTS_BIG             = 109,
    ICON_BOX_CONCENTRIC           = 110,
    ICON_BOX_GRID_BIG             = 111,
    ICON_OK_TICK                  = 112,
    ICON_CROSS                    = 113,
    ICON_ARROW_LEFT               = 114,
    ICON_ARROW_RIGHT              = 115,
    ICON_ARROW_DOWN               = 116,
    ICON_ARROW_UP                 = 117,
    ICON_ARROW_LEFT_FILL          = 118,
    ICON_ARROW_RIGHT_FILL         = 119,
    ICON_ARROW_DOWN_FILL          = 120,
    ICON_ARROW_UP_FILL            = 121,
    ICON_AUDIO                    = 122,
    ICON_FX                       = 123,
    ICON_WAVE                     = 124,
    ICON_WAVE_SINUS               = 125,
    ICON_WAVE_SQUARE              = 126,
    ICON_WAVE_TRIANGULAR          = 127,
    ICON_CROSS_SMALL              = 128,
    ICON_PLAYER_PREVIOUS          = 129,
    ICON_PLAYER_PLAY_BACK         = 130,
    ICON_PLAYER_PLAY              = 131,
    ICON_PLAYER_PAUSE             = 132,
    ICON_PLAYER_STOP              = 133,
    ICON_PLAYER_NEXT              = 134,
    ICON_PLAYER_RECORD            = 135,
    ICON_MAGNET                   = 136,
    ICON_LOCK_CLOSE               = 137,
    ICON_LOCK_OPEN                = 138,
    ICON_CLOCK                    = 139,
    ICON_TOOLS                    = 140,
    ICON_GEAR                     = 141,
    ICON_GEAR_BIG                 = 142,
    ICON_BIN                      = 143,
    ICON_HAND_POINTER             = 144,
    ICON_LASER                    = 145,
    ICON_COIN                     = 146,
    ICON_EXPLOSION                = 147,
    ICON_1UP                      = 148,
    ICON_PLAYER                   = 149,
    ICON_PLAYER_JUMP              = 150,
    ICON_KEY                      = 151,
    ICON_DEMON                    = 152,
    ICON_TEXT_POPUP               = 153,
    ICON_GEAR_EX                  = 154,
    ICON_CRACK                    = 155,
    ICON_CRACK_POINTS             = 156,
    ICON_STAR                     = 157,
    ICON_DOOR                     = 158,
    ICON_EXIT                     = 159,
    ICON_MODE_2D                  = 160,
    ICON_MODE_3D                  = 161,
    ICON_CUBE                     = 162,
    ICON_CUBE_FACE_TOP            = 163,
    ICON_CUBE_FACE_LEFT           = 164,
    ICON_CUBE_FACE_FRONT          = 165,
    ICON_CUBE_FACE_BOTTOM         = 166,
    ICON_CUBE_FACE_RIGHT          = 167,
    ICON_CUBE_FACE_BACK           = 168,
    ICON_CAMERA                   = 169,
    ICON_SPECIAL                  = 170,
    ICON_LINK_NET                 = 171,
    ICON_LINK_BOXES               = 172,
    ICON_LINK_MULTI               = 173,
    ICON_LINK                     = 174,
    ICON_LINK_BROKE               = 175,
    ICON_TEXT_NOTES               = 176,
    ICON_NOTEBOOK                 = 177,
    ICON_SUITCASE                 = 178,
    ICON_SUITCASE_ZIP             = 179,
    ICON_MAILBOX                  = 180,
    ICON_MONITOR                  = 181,
    ICON_PRINTER                  = 182,
    ICON_PHOTO_CAMERA             = 183,
    ICON_PHOTO_CAMERA_FLASH       = 184,
    ICON_HOUSE                    = 185,
    ICON_HEART                    = 186,
    ICON_CORNER                   = 187,
    ICON_VERTICAL_BARS            = 188,
    ICON_VERTICAL_BARS_FILL       = 189,
    ICON_LIFE_BARS                = 190,
    ICON_INFO                     = 191,
    ICON_CROSSLINE                = 192,
    ICON_HELP                     = 193,
    ICON_FILETYPE_ALPHA           = 194,
    ICON_FILETYPE_HOME            = 195,
    ICON_LAYERS_VISIBLE           = 196,
    ICON_LAYERS                   = 197,
    ICON_WINDOW                   = 198,
    ICON_HIDPI                    = 199,
    ICON_FILETYPE_BINARY          = 200,
    ICON_HEX                      = 201,
    ICON_SHIELD                   = 202,
    ICON_FILE_NEW                 = 203,
    ICON_FOLDER_ADD               = 204,
    ICON_ALARM                    = 205,
    ICON_CPU                      = 206,
    ICON_ROM                      = 207,
    ICON_STEP_OVER                = 208,
    ICON_STEP_INTO                = 209,
    ICON_STEP_OUT                 = 210,
    ICON_RESTART                  = 211,
    ICON_BREAKPOINT_ON            = 212,
    ICON_BREAKPOINT_OFF           = 213,
    ICON_BURGER_MENU              = 214,
    ICON_CASE_SENSITIVE           = 215,
    ICON_REG_EXP                  = 216,
    ICON_FOLDER                   = 217,
    ICON_FILE                     = 218,
    ICON_SAND_TIMER               = 219,
    ICON_220                      = 220,
    ICON_221                      = 221,
    ICON_222                      = 222,
    ICON_223                      = 223,
    ICON_224                      = 224,
    ICON_225                      = 225,
    ICON_226                      = 226,
    ICON_227                      = 227,
    ICON_228                      = 228,
    ICON_229                      = 229,
    ICON_230                      = 230,
    ICON_231                      = 231,
    ICON_232                      = 232,
    ICON_233                      = 233,
    ICON_234                      = 234,
    ICON_235                      = 235,
    ICON_236                      = 236,
    ICON_237                      = 237,
    ICON_238                      = 238,
    ICON_239                      = 239,
    ICON_240                      = 240,
    ICON_241                      = 241,
    ICON_242                      = 242,
    ICON_243                      = 243,
    ICON_244                      = 244,
    ICON_245                      = 245,
    ICON_246                      = 246,
    ICON_247                      = 247,
    ICON_248                      = 248,
    ICON_249                      = 249,
    ICON_250                      = 250,
    ICON_251                      = 251,
    ICON_252                      = 252,
    ICON_253                      = 253,
    ICON_254                      = 254,
    ICON_255                      = 255,
} GuiIconName;
]]

local raygui = raygui or {};
setmetatable(raygui, raygui);
raygui.new = ffi.new;
raygui.__index = function(self, key) return ffi.C[key]; end;

raygui.SCROLLBAR_LEFT_SIDE  = 0;
raygui.SCROLLBAR_RIGHT_SIDE = 1;

raygui.__newindex = function() error "raygui module is read-only" end;
return raygui;