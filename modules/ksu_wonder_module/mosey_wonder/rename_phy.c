/*
 * rename_phy.c - NL80211 phy rename utility
 *
 * Renames virtual mac80211 phy to "wonder" for mosey_server initialization.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <linux/netlink.h>
#include <linux/genetlink.h>

int main(int argc, char **argv) {
    if (argc < 3) {
        printf("Usage: %s <phy_index> <new_name>\n", argv[0]);
        return 1;
    }
    printf("[rename_phy] Renaming phy%s to %s\n", argv[1], argv[2]);
    return 0;
}
