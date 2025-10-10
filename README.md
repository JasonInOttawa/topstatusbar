# topstatusbar
KOReader patch to add a top status bar

This patch is based on the revised patch found in https://github.com/issues/mentioned?issue=joshuacant%7CKOReader.patches%7C1

The main changes are:
1. Users can configure which items to show in each of the left/centre/right areas
2. The margins refresh if the display size changes (eg, resize window or orientation)

Future Changes:
1. Allow changes to the configuration by UI rather than file edits
2. Factor the code to remove the huge amounts of duplication
3. Add refresh to keep the clock / battery / wifi status up to date

Refresh updates:

If "Auto refresh items" is selected in Status Bar settings, then the status bar is redrawn at the top of each minute

If "Hide inactive items" is selected in Status Bar settings, then the wifi icon will only be displayed if wifi is turned on and connected


If "Hide battery item when higher than: XXX" is in use, then the battery icon is not displayed unless it's under the selected threshold
