/*========================================================================
 * LSD Menu System
 * © 2022 Thomas Pallis SL Message to thomas.pallis
 *------------------------------------------------------------------------
 * Menu and dialog system interface for use in the Pallis Virtual Table 
 * Top, with inspiration and some code from Nargus Asturias' 
 * SIMPLE DIALOG MODULE
 *========================================================================
 */

/*
 * Menu Types
 * CMD | message                  : Command Menu
 * VAL | message | variable name  : Set Variable/Option menu
 * TXT | message | variable name  : Set Variable/Text menu
 *------------------------------------------------------------------------
 * Menu Element Types
 * MNU | text | menu name                     : Brings up the named submenu
 * LNK | text | post | channel | message      : sends the link message on the channel 
 * TOG | text | post | variable name          : toggles variables
 * OPT | text | variable name | ... n/v pairs : shows options
 */

//========================================================================
#define LNK_SHOWMENU     40000
#define LNK_CLOSEMENU    40001
#define LNK_PUSHMENU     40002
#define LNK_ADDMENU      40010
#define LNK_DELMENU      40011
#define LNK_ADDREPL      40020
#define LNK_DELREPL      40021
#define LNK_MENUOPENED   50000
#define LNK_MENUCLOSED   50001

#define MENU_MENU       "MNU"
#define MENU_LINK       "LNK"
#define MENU_TOGGLE     "TOG"
#define MENU_TEXT       "TXT"    
#define MENU_SET        "SET"
#define MENU_RADIO      "RDO"
#define MENU_OPTION     "OPT"
#define MENU_NOOP       "NOP"

#define MENU_SEPERATOR  "␑" // U+2411
#define MENU_RECORDSEP  "␒" // U+2412
#define MENU_UNITSEP    "␓" // U+2413

//------------------------------------------------------------------------
// post menu actions
#define MENU_POST_CLOSE "CLS"
#define MENU_POST_POP   "POP"
#define MENU_POST_RESHOW "RSH"
#define MENU_POST_HIDE  "HID"

//========================================================================
string packMenuItem(string type, string text, list opts)
{
    list menu_item = [ text, type ];
    
    if (type == MENU_MENU)
    {
        menu_item += [llList2String(opts, 0), llList2String(opts, 1)];
    }
    else if (type == MENU_LINK)
    {
        integer link_no = LINK_SET;
        if (llList2String(opts, 0) != "")
            link_no = llList2Integer(opts, 0);
        menu_item += [ llList2String(opts, 3), link_no, 
            llList2Integer(opts, 1), llList2String(opts, 2), llList2String(opts, 4)];
    }
    else if (type == MENU_TOGGLE)
    {
        menu_item += [ llList2String(opts, 1), llList2String(opts, 0) ];
    }
    else if (type == MENU_TEXT)
    {
        menu_item += [ llList2String(opts, 2), llList2String(opts, 0), llList2String(opts, 1) ];
    }
    else if ((type == MENU_SET) || (type == MENU_RADIO))
    {   
        menu_item += [ llList2String(opts, 2), llList2String(opts, 0), llList2String(opts, 1)];
    }
    else if (type == MENU_OPTION)
    {   // in: 
        menu_item += [ "" ] + opts;
    }
    else if (type == MENU_NOOP)
    {
        menu_item += [ "" ];
    }
    else
    {
        return "";
    }
    return llDumpList2String(menu_item, MENU_RECORDSEP);
}

string packMenu(string menu_name, string menu_type, string message, string variable, string post, list buttons)
{
    list menu_def = [menu_name, menu_type, message, post, variable ] + buttons;

    return llDumpList2String(menu_def, MENU_SEPERATOR);
}

