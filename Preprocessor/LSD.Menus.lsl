/*========================================================================
 * LSD Menu System
 * © 2022 Thomas Pallis SL Message to thomas.pallis
 *------------------------------------------------------------------------
 * Menu and dialog system for use in the Pallis Virtual Table Top, with 
 * inspiration and some code from Nargus Asturias' SIMPLE DIALOG MODULE
 *========================================================================
 */

#include "PVTT.Menus.Interface.lsl"

//========================================================================
#define MENU_PREFIX     "_.MENU."
#define MENU_TOGGLE_0   "⃝"
#define MENU_TOGGLE_1   "◉"

#define MENU_PAGE_BACK  "⟸"
#define MENU_PAGE_NEXT  "⟹"
#define MENU_PAGE_UP    "⇧"
#define MENU_PAGE_CLOSE "Close"

#define MENU_BLANK      "◌"

#define MENU_TIMEOUT    180.0

#define VER_MENUS    "1.0.0.7"
//========================================================================
integer MENU_LISTEN_CTRL = 0;
list MENU_STACK = [];


//========================================================================
string  CUR_MENU_NAME = "";
string  CUR_MENU_TYPE = "";
string  CUR_MENU_MESSAGE = "";
string  CUR_MENU_VARIABLE = "";
string  CUR_MENU_POST = "";
list    CUR_MENU_CMDS = [];
integer CUR_MENU_PAGE = 0;
integer CUR_MENU_PAGE_COUNT = 0;
list    CUR_PAGE_TEXT = [];
integer CUR_PAGE_START = 0;
integer CUR_PAGE_END = 0;

//========================================================================
// text | MNU | menu name |var override
// text | LNK | post | link_no | msg_no | message
// text | TOG | post | name
// text | SET | post | name | value

//========================================================================
// [ type | message | post | variable | ... ]
buildMenu(string menu_name, list menu_def)
{
    CUR_MENU_NAME = menu_name;
    CUR_MENU_TYPE = llList2String(menu_def, 0);
    CUR_MENU_MESSAGE = llList2String(menu_def, 1);
    CUR_MENU_POST = llList2String(menu_def, 2);
    string next_menu_var = llList2String(menu_def, 3);
    if (next_menu_var != "_PARENT_")
        CUR_MENU_VARIABLE = next_menu_var;
    CUR_MENU_CMDS = llDeleteSubList(menu_def, 0, 3);
}

//========================================================================
/* Show a dialog (or text input) box to the avatar identified by target_id
 * and configure the script to listend for their response. 
 */
showMenuTo( key target_id, string message, list buttons)
{
    if (MENU_LISTEN_CTRL)
        llListenRemove(MENU_LISTEN_CTRL);
    // The channel isn't a secret, it just needs a reasonable chance of being unique
    integer channel = llHash( (string)target_id + ":" + llGetTimestamp());
    MENU_LISTEN_CTRL = llListen(channel, "", target_id, "");
    
    if (buttons == [])
        llTextBox(target_id, message, channel);
    else
        llDialog(target_id, message, buttons, channel);
    llMessageLinked(LINK_SET, LNK_MENUOPENED, CUR_MENU_NAME, target_id);
    llSetTimerEvent(MENU_TIMEOUT);
}

/** get the span of the buttons on a page (start, end) and the number of pages
 * in the entire menu.
 */
list getButtonPageRange(integer button_count, integer page, integer nav_buttons)
{
    if (button_count < 9)
    {
        return [0, button_count, 1];
    }
    
    integer page_start = page * 9;
    integer page_end = (page + 1) * 9;
    integer page_count = (button_count / 9) + 1;
    if (page_end > button_count)
        page_end = button_count;
    
    return [ page_start, page_end, page_count ];
}

list prepareButtons(integer start, integer end)
{
    list button_text = [];
    integer index;
    for (index = start; index < end; index++)
    {
        list item = llParseStringKeepNulls(
                llList2String(CUR_MENU_CMDS, index), [ MENU_RECORDSEP ], []);
        string label = llGetSubString(llStringTrim(replaceVariables( llList2String(item, 0), 
                llParseStringKeepNulls(llLinksetDataRead(MENU_PREFIX+"REPLACEMENT"), 
                [MENU_SEPERATOR], [])), STRING_TRIM), 0, 20);
        string type = llList2String(item, 1);
        if ((type == MENU_TOGGLE) || (type == MENU_RADIO))
        {
            integer value = FALSE;
            string var_name = llList2String(item, 3);
            if (var_name == "")
                var_name = CUR_MENU_VARIABLE;
            if (type == MENU_TOGGLE)
                value = (integer)llLinksetDataRead(var_name);
            else 
                value = (llLinksetDataRead(var_name) == llList2String(item, 4));
            
            if (value)
                label = MENU_TOGGLE_1 + " " + label;
            else
                label = MENU_TOGGLE_0 + " " + label;
        }
        if (label == "")
            label = MENU_BLANK;
        button_text += [ label ];
    }
    return button_text;
}

list getNavButtons(integer page_no)
{
    string close_or_up = MENU_PAGE_CLOSE;
    if (llGetListLength(MENU_STACK) > 0)
        close_or_up = MENU_PAGE_UP;

    if (CUR_MENU_PAGE_COUNT == 1)
        return [ MENU_BLANK, close_or_up, MENU_BLANK ];
    
    list navigate = [];
    if (page_no > 0)
        navigate = [ MENU_PAGE_BACK ];
    else 
        navigate = [ MENU_BLANK ];
    navigate += [ close_or_up ];
    if (page_no == (CUR_MENU_PAGE_COUNT-1))
        navigate += [ MENU_BLANK ];
    else 
        navigate += [ MENU_PAGE_NEXT ];
    
    return navigate;
}

integer pushMenu(key target_id, string menu_name, string var_override, list menu_def)
{
    if (CUR_MENU_NAME != "")
    {
        list push_menu = [ CUR_MENU_NAME, CUR_MENU_PAGE, CUR_MENU_VARIABLE ];
        MENU_STACK += [ llDumpList2String(push_menu, MENU_SEPERATOR) ];
    }
    if (!doMenu(target_id, menu_name, 0, var_override, menu_def))
    {
        popMenu(target_id);
        return FALSE;
    }
    return TRUE;
}

popMenu(key target_id)
{
    if (llGetListLength(MENU_STACK) == 0)
    {
        return;
    }
    list pop_menu = llParseStringKeepNulls(
            llList2String(MENU_STACK, -1), [MENU_SEPERATOR], []);
    MENU_STACK = llDeleteSubList(MENU_STACK, -1, -1);
    if (pop_menu == [])
    {
        showActiveMenu(target_id);
        return;
    }
    
    doMenu(target_id, llList2String(pop_menu, 0), llList2Integer(pop_menu, 1), 
        llList2String(pop_menu, 2), []);
}

pageMenu(key target_id, integer page)
{
    CUR_MENU_PAGE += page;
    if (CUR_MENU_PAGE < 0)
        CUR_MENU_PAGE = 0;
    else if (CUR_MENU_PAGE > CUR_MENU_PAGE_COUNT-1)
        CUR_MENU_PAGE = CUR_MENU_PAGE_COUNT-1;
    list pagination = getButtonPageRange(llGetListLength(CUR_MENU_CMDS), CUR_MENU_PAGE, TRUE);
    CUR_PAGE_START = llList2Integer(pagination, 0);
    CUR_PAGE_END = llList2Integer(pagination, 1);
    
    showActiveMenu(target_id);
}

integer doMenu(key target_id, string menu_name, integer page, string var_override, list menu_def)
{
    if (menu_def == [])
    {
        menu_def = llParseStringKeepNulls(
                llLinksetDataRead(MENU_PREFIX + menu_name), [ MENU_SEPERATOR ], []);
        if (llGetListLength(menu_def) == 0)
            return FALSE;
    }
    buildMenu(menu_name, menu_def);
    if (var_override != "")
        CUR_MENU_VARIABLE = var_override;
    list pagination = getButtonPageRange(llGetListLength(CUR_MENU_CMDS), 0, TRUE);
    
    if (page < 0)
        page = 0;
    
    CUR_MENU_PAGE = page;
    CUR_PAGE_START = llList2Integer(pagination, 0);
    CUR_PAGE_END = llList2Integer(pagination, 1);
    CUR_MENU_PAGE_COUNT = llList2Integer(pagination, 2);
    
    if (CUR_MENU_PAGE > CUR_MENU_PAGE_COUNT)
        CUR_MENU_PAGE = CUR_MENU_PAGE_COUNT;
    
    showActiveMenu(target_id);
    return TRUE;
}

showActiveMenu(key target_id)
{
    CUR_PAGE_TEXT = prepareButtons(CUR_PAGE_START, CUR_PAGE_END);
    list nav_buttons = [];
    if (CUR_MENU_TYPE != MENU_TEXT)
        nav_buttons = getNavButtons(CUR_MENU_PAGE);
    showMenuTo( target_id, replaceVariables(CUR_MENU_MESSAGE, 
            llParseStringKeepNulls(llLinksetDataRead(MENU_PREFIX+"REPLACEMENT"), 
            [MENU_SEPERATOR], [])), nav_buttons + CUR_PAGE_TEXT);
}

closeMenu(integer message)
{
    if (message)
        llMessageLinked(LINK_SET, LNK_MENUCLOSED, CUR_MENU_NAME, NULL_KEY);
    CUR_MENU_NAME = "";
    CUR_MENU_TYPE = "";
    CUR_MENU_MESSAGE = "";
    CUR_MENU_VARIABLE = "";
    CUR_MENU_POST = "";
    CUR_MENU_CMDS = [];
    CUR_MENU_PAGE = 0;
    CUR_MENU_PAGE_COUNT = 0;
    CUR_PAGE_TEXT = [];
    CUR_PAGE_START = 0;
    CUR_PAGE_END = 0;
    if (MENU_LISTEN_CTRL)
        llListenRemove(MENU_LISTEN_CTRL);
    MENU_LISTEN_CTRL = 0;
    llSetTimerEvent(0.0);
}



//========================================================================
processMenuSelection(string name, key id, string message)
{
    string post_action = CUR_MENU_POST;
    if (CUR_MENU_TYPE == MENU_TEXT)
    {
        if (llGetListLength(CUR_MENU_CMDS) == 0)
            llLinksetDataWrite(CUR_MENU_VARIABLE, message);
        else 
        {
            string action = llList2String(CUR_MENU_CMDS, 0);
            list action_def = llParseStringKeepNulls(action, [ MENU_RECORDSEP ], []);
            action = llList2String(action_def, 1);
            if (action == MENU_LINK)
            {
                string lnk_message = replaceVariables(llList2String(action_def, 5), 
                    ["TEXT", message] +
                    llParseStringKeepNulls(llLinksetDataRead(MENU_PREFIX+"REPLACEMENT"), 
                        [MENU_SEPERATOR], []));
                llMessageLinked(llList2Integer(action_def, 3), llList2Integer(action_def, 4),
                        lnk_message, id);
            }
        }
    }
    else
    {
        integer index = llListFindList(CUR_PAGE_TEXT, [message]);
        if (index == -1)
        {   // I'm not sure how this could ever be the case.  But account for it.
            showActiveMenu(id);
            return;
        }
        
        index += CUR_PAGE_START;
        string action = llList2String(CUR_MENU_CMDS, index);
        list action_def = llParseStringKeepNulls(action, [ MENU_RECORDSEP ], []);
        action = llList2String(action_def, 1);
        post_action = llList2String(action_def, 2);
        if (post_action == "")
            post_action = CUR_MENU_POST;
        
        if (action == MENU_MENU)
        {   //  text | MNU | menu name |var override,  Push the current dialog and show the next
            pushMenu(id, llList2String(action_def, 2), llList2String(action_def, 3), []);
            return;
        }
        else if (action == MENU_LINK)
        {   // text | LNK | post | link_no | msg_no | message | confirm
            if (llList2String(action_def, 6) == "")
            {
                string lnk_message = replaceVariables(llList2String(action_def, 5), 
                        llParseStringKeepNulls(llLinksetDataRead(MENU_PREFIX+"REPLACEMENT"), 
                        [MENU_SEPERATOR], []));
                llMessageLinked(llList2Integer(action_def, 3), llList2Integer(action_def, 4),
                        lnk_message, id);
            }
            else
            {
                string confirmation = replaceVariables(llList2String(action_def, 6), 
                        llParseStringKeepNulls(llLinksetDataRead(MENU_PREFIX+"REPLACEMENT"), 
                        [MENU_SEPERATOR], [])) + 
                        "\nDo you wish to continue?";
                pushMenu( id, "", "", [ MENU_MENU, confirmation, MENU_POST_CLOSE, "",
                    llDumpList2String(["Yes"] + llList2List(action_def, 1, 5), MENU_RECORDSEP),
                    packMenuItem(MENU_NOOP, "No", [])]);
                return;
            }
        }
        else if ((action == MENU_TOGGLE) || (action == MENU_SET) || (action == MENU_RADIO))
        {   // text | TOG | post | name          : toggles variables
            // text | SET | post | name | value  : sets variables
            string var_name = llList2String(action_def, 3);
            if (var_name == "")
                var_name = CUR_MENU_VARIABLE;
            string var_value = llLinksetDataRead(var_name);
            if (action == MENU_TOGGLE)
                var_value = (string)(!(integer)var_value);
            else 
                var_value = llList2String(action_def, 4);

            llLinksetDataWrite(var_name, var_value);
        }
        else if (action == MENU_TEXT)
        {   // text | TOG | post | name
            string button_text = llList2String(action_def, 0);
            string var_name = llList2String(action_def, 3);
            string text_message = llList2String(action_def, 4);
            if (text_message == "")
                text_message = button_text + ": {" + var_name + "}";
            if ((post_action == "") || (post_action == MENU_POST_RESHOW))
                post_action = MENU_POST_POP;
            pushMenu( id, "", "", [ MENU_TEXT, text_message, post_action, var_name ]);
            return;
        }
        else if (action == MENU_OPTION)
        {   // text | OPT | post | name | dialog_text... n/v pairs : shows options
            string button_text = llList2String(action_def, 0);
            string var_name = llList2String(action_def, 3);
            string text_message = llList2String(action_def, 4);
            if (var_name == "")
                var_name = CUR_MENU_VARIABLE;
            if (text_message == "")
                text_message = button_text + ": {" + var_name + "}";

            list options = llDeleteSubList(action_def, 0, 4);
            list buttons = [];
            integer count = llGetListLength(options);
            integer index;
            for (index = 0; index < count; index += 2)
            {   
                string opt_text = llList2String(options, index);
                string opt_val = llList2String(options, index+1);
                if (opt_text == "")
                    opt_text = "<" + opt_val + ">";
                string button = packMenuItem(MENU_RADIO, opt_text, [ "", opt_val ]);
                if (button != "")
                    buttons += button;
            }
            pushMenu( id, "", "", [ MENU_MENU, text_message, MENU_POST_POP, var_name ] + buttons);
            return;
        }
    }
    
    if (post_action == MENU_POST_POP)
        popMenu(id);
    //else if (post_action == "POP2")
    //    doublePopActiveDialog();
    else if (post_action == MENU_POST_CLOSE)
        closeMenu(TRUE);
    else if (post_action == MENU_POST_HIDE)
        return;
    else
        showActiveMenu(id);
}


//========================================================================
string replaceVariables(string source, list replacements)
{
    string result = "";
    list delims_open = [ "{", "[", "<" ];
    list delims_close = [ "}", "]", ">" ];
    
    list parsed = llParseStringKeepNulls(source, [], delims_open + delims_close);
    
    integer count = llGetListLength(parsed);
    if (count == 1)
        return source;
    integer index = 0;
    while (index < count)
    {
        string token = llList2String(parsed, index);
        integer token_type = llListFindList(delims_open, [token]);
        if (token_type == -1)
        {   // not an opening token
            result += token;
            index += 1;
        }
        else
        {   // check for end token
            if (llList2String(parsed, index + 2) == llList2String(delims_close, token_type))
            {   // matching close token
                string var_name = llStringTrim(llList2String(parsed, index + 1), STRING_TRIM);
                if (llGetSubString(var_name, 0, 5)  == "_MENU_")
                {
                    var_name = CUR_MENU_VARIABLE + llDeleteSubString(var_name, 0, 5);
                }
                string var_value = "";
                if (token_type == 2)
                {
                    integer repl_index = llListFindList(replacements, [var_name]);
                    if (repl_index != -1)
                        var_value = llList2String(replacements, repl_index+1);
                }
                else 
                    var_value = llLinksetDataRead(var_name);
                if (var_value == "")
                {
                    result += token;
                    index += 1;
                }
                else
                {
                    if (token_type == 1)
                    {
                        integer repl_index = llListFindList(replacements, [var_value]);
                        if (repl_index != -1)
                            var_value = llList2String(replacements, repl_index+1);
                    }
                    result += var_value;
                    index += 3;
                }
            }
            else
            {   // no close token
                result += token;
                index += 1;
            }
        }
    }
    
    return result;
}

//========================================================================
//initialize()
//{
//    //llOwnerSay( llGetScriptName() + ":\n" +
//    //    "\tused: " + (string)llGetUsedMemory() + "\n" +
//    //    "\tfree: " + (string)llGetFreeMemory());
//    CUR_MENU_NAME = "";
//    CUR_MENU_TYPE = "";
//    CUR_MENU_MESSAGE = "";
//    CUR_MENU_VARIABLE = "";
//    CUR_MENU_POST = "";
//    CUR_MENU_CMDS = [];
//    CUR_MENU_PAGE = 0;
//    CUR_MENU_PAGE_COUNT = 0;
//    CUR_PAGE_TEXT = [];
//    CUR_PAGE_START = 0;
//    CUR_PAGE_END = 0;
//}

//------------------------------------------------------------------------
default
{
    state_entry()
    {
        closeMenu(FALSE);
        llLinksetDataWrite("VER.MENUS", llGetScriptName() + "␞" + VER_MENUS);
    }

    on_rez(integer param)
    {
        llResetScript();
    }
    
    listen(integer channel, string name, key id, string message)
    {
        if (message == MENU_BLANK)
        {
            showActiveMenu(id);
        }
        if (message == MENU_PAGE_CLOSE)
        {
            closeMenu(TRUE);
        }
        else if (message == MENU_PAGE_BACK)
        {   
            pageMenu(id, -1);
        }
        else if (message == MENU_PAGE_NEXT)
        {
            pageMenu(id, 1);
        }
        else if (message == MENU_PAGE_UP)
        {
            popMenu(id);
        }
        else 
        {   
            processMenuSelection(name, id, message);
        }
    }
    
    link_message( integer sender_num, integer num, string str, key id )
    {
        llLinksetDataWrite("VER.MENUS", llGetScriptName() + "␞" + VER_MENUS);
    
        if (num == LNK_SHOWMENU)
        {
            list menu_def = llParseStringKeepNulls(str, [MENU_SEPERATOR], []);
            str = "";   // don't need this anymore.
            string menu_name = llList2String(menu_def, 0);
            menu_def = llDeleteSubList(menu_def, 0, 0);
            MENU_STACK = [];
            if (doMenu(id, menu_name, 0, "", menu_def) &&
                (menu_def != []) && (menu_name != ""))
            {
                llLinksetDataWrite(MENU_PREFIX+menu_name, llDumpList2String(menu_def, MENU_SEPERATOR));
            }
        }
        else if (num == LNK_PUSHMENU)
        {
            list menu_def = llParseStringKeepNulls(str, [MENU_SEPERATOR], []);
            str = "";   // don't need this anymore.
            string menu_name = llList2String(menu_def, 0);
            menu_def = llDeleteSubList(menu_def, 0, 0);
            if (pushMenu(id, menu_name, "", menu_def) && 
                (menu_def != []) && (menu_name != ""))
            {
                llLinksetDataWrite(MENU_PREFIX+menu_name, llDumpList2String(menu_def, MENU_SEPERATOR));
            }
        }
        else if (num == LNK_CLOSEMENU)
        {
            closeMenu(TRUE);
        }
        else if (num == LNK_ADDMENU)
        {
            list menu_def = llParseStringKeepNulls(str, [MENU_SEPERATOR], []);
            str = "";   // don't need this anymore.
            string menu_name = llList2String(menu_def, 0);
            llGetFreeMemory();
            menu_def = llDeleteSubList(menu_def, 0, 0);
            llLinksetDataWrite(MENU_PREFIX+menu_name, llDumpList2String(
                    menu_def, MENU_SEPERATOR));
        }
        else if (num == LNK_DELMENU)
        {
            if (str != "")
            {
                llLinksetDataDelete(MENU_PREFIX + str);
            }
            else
            {
                list keys = llLinksetDataFindKeys("^_\\.MENU\\.", 0, 0);
                integer count = llGetListLength(keys);
                integer index;
                for (index = 0; index < count; index++)
                {
                    llLinksetDataDelete(llList2String(keys, index));
                }
            }
        }
        else if (num == LNK_ADDREPL)
        {
            integer resort = FALSE;
            list nvpairs = llParseStringKeepNulls(str, [",", "=", MENU_SEPERATOR], []);
            integer count = llGetListLength(nvpairs);
            integer index = 0;
            list replacements = llParseStringKeepNulls(
                    llLinksetDataRead(MENU_PREFIX+"REPLACEMENT"), [MENU_SEPERATOR], []);
            
            for (index = 0; index < count; index += 2)
            {
                list nvpair = llList2List(nvpairs, index, index+1);
                nvpair = [ llStringTrim(llList2String(nvpair, 0), STRING_TRIM), 
                        llStringTrim(llList2String(nvpair, 1), STRING_TRIM) ];
                if (llList2String(nvpair, 0) != "")
                {
                    list keys = llList2ListStrided(replacements, 0, -1, 2);
                    integer index = llListFindList(keys, [llList2String(nvpair, 0)]);
                    if (index == -1)
                    {
                        if (llList2String(nvpair, 1) != "")
                        {
                            replacements += nvpair;
                            resort = TRUE;
                        }
                    }
                    else
                    {
                        index *= 2;
                        if (llList2String(nvpair, 1) == "")
                            replacements = llDeleteSubList(replacements, index, index+1);
                        else
                            replacements = llListReplaceList(replacements, nvpair, index, index+1);
                    }
                }
            }
            if (resort)
                replacements = llListSort(replacements, 2, TRUE);

            llLinksetDataWrite(MENU_PREFIX+"REPLACEMENT", llDumpList2String(replacements, MENU_SEPERATOR));
        }
        else if (num == LNK_DELREPL)
        {
            if (str == "")
            {
                llLinksetDataDelete(MENU_PREFIX+"REPLACEMENT");
            }
            else
            {
                list names = llParseStringKeepNulls(str, [",", MENU_SEPERATOR], []);
                list replacements = llParseStringKeepNulls(
                        llLinksetDataRead(MENU_PREFIX+"REPLACEMENT"), [MENU_SEPERATOR], []);
                integer count = llGetListLength(names);
                integer index;
                for (index = 0; index < count; index++)
                {
                    string name = llStringTrim(llList2String(names, index), STRING_TRIM);
                    list keys = llList2ListStrided(replacements, 0, -1, 2);
                    integer rindex = llListFindList(keys, [ name ]);
                    if (rindex != -1)
                    {
                        rindex *= 2;
                        replacements = llDeleteSubList(replacements, rindex, rindex+1);
                    }
                }
                llLinksetDataWrite(MENU_PREFIX+"REPLACEMENT", llDumpList2String(replacements, MENU_SEPERATOR));
            }
        }
        llSleep(0.1);
    }
   
    timer()
    {
        llMessageLinked(LINK_THIS, LNK_CLOSEMENU, "", NULL_KEY);
    }
}
