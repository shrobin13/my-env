# Goodix 27c6:538d Fingerprint Setup on Omarchy / Arch Linux

> **Status:** Working for `sudo` and the Omarchy Quickshell lock
> screen.\
> **Not yet configured:** SDDM greeter login.\
> **Hardware:** Dell Inspiron 5502 --- Goodix USB fingerprint sensor
> `27c6:538d`.

This document records the working configuration, the exact libfprint
fork and commit used, the installation layout, the PAM configuration,
and the validation steps. Keep it as a recovery/reference guide if the
setup needs to be reproduced later.

------------------------------------------------------------------------

## 1. Working result

The following has been verified on this machine:

  -----------------------------------------------------------------------
  Component               Result                  Evidence
  ----------------------- ----------------------- -----------------------
  Goodix sensor detection Working                 Sensor detected as
                                                  Goodix TLS Fingerprint
                                                  Sensor 53XD

  Firmware / TLS          Working                 Diagnostic tool
  initialization                                  reported valid PSK and
                                                  successful TLS
                                                  connection

  Fingerprint enrollment  Working                 16 enrollment samples
                                                  completed and saved

  `fprintd-verify`        Working                 Returned `verify-match`

  `sudo` fingerprint      Working                 `sudo -k; sudo -v`
  authentication                                  prompted for the right
                                                  index finger and exited
                                                  with status `0`

  Omarchy Quickshell lock Working                 Fingerprint
  screen                                          successfully unlocked
                                                  the lock screen

  SDDM greeter            Not configured yet      Autologin disabled for
  fingerprint login                               physical security; greeter
                                                  uses standard password
  -----------------------------------------------------------------------

The enrolled print is the **right index finger** for Linux user `light`.

## 2. Exact driver source used

The working driver came from this fork and branch:

-   Repository: <https://github.com/lbssousa/libfprint>
-   Branch: `goodix-538d-sigfm-gtls`
-   Installed commit: `7ba5cad202b7559589c10104fdc8fdbe06c46d72`
-   Commit URL:
    <https://github.com/lbssousa/libfprint/commit/7ba5cad202b7559589c10104fdc8fdbe06c46d72>
-   Branch URL:
    <https://github.com/lbssousa/libfprint/tree/goodix-538d-sigfm-gtls>

Important driver and matcher files at that commit:

-   [`goodix53xd.c`](https://github.com/lbssousa/libfprint/blob/7ba5cad202b7559589c10104fdc8fdbe06c46d72/libfprint/drivers/goodixtls/goodix53xd.c)
-   [`goodix53xd.h`](https://github.com/lbssousa/libfprint/blob/7ba5cad202b7559589c10104fdc8fdbe06c46d72/libfprint/drivers/goodixtls/goodix53xd.h)
-   [`goodix53xd_match.c`](https://github.com/lbssousa/libfprint/blob/7ba5cad202b7559589c10104fdc8fdbe06c46d72/libfprint/drivers/goodixtls/goodix53xd_match.c)
-   [`goodix53xd_match.h`](https://github.com/lbssousa/libfprint/blob/7ba5cad202b7559589c10104fdc8fdbe06c46d72/libfprint/drivers/goodixtls/goodix53xd_match.h)
-   [`sigfm.c`](https://github.com/lbssousa/libfprint/blob/7ba5cad202b7559589c10104fdc8fdbe06c46d72/libfprint/sigfm/sigfm.c)

The fork's libfprint version was `1.94.100` and it included the
`goodixtls53xd` driver and SIGFM matcher.

### Related original diagnostic project

The initial low-level sensor/firmware diagnostic work used:

-   Repository: <https://github.com/goodix-fp-linux-dev/goodix-fp-dump>

The diagnostic identified the sensor firmware as:

``` text
GF5298_GM168SEC_APP_13016
```

The diagnostic eventually reported:

``` text
Valid PSK: True
TLS connection succeeded
mcu_get_image() succeeded
```

Those diagnostics established that the sensor could be initialized and
communicate securely. The final fprintd integration was achieved with
the `lbssousa/libfprint` fork above.

**Do not rerun firmware initialization, erase, or reflash commands just
to restore normal fingerprint authentication.** They were not needed
after the sensor was initialized and could risk changing persistent
device state.

## 3. Build and installation layout

The source checkout is:

``` text
~/src/libfprint-538d
```

The installed custom library is:

``` text
/opt/libfprint-538d/lib/libfprint-2.so.2.0.0
```

Its SONAME symlink is:

``` text
/opt/libfprint-538d/lib/libfprint-2.so.2
```

The build used Meson and Ninja, with these important settings:

  Setting             Value
  ------------------- -----------------------
  Prefix              `/opt/libfprint-538d`
  Library directory   `lib`
  Driver selection    `goodixtls53xd`
  Introspection       Enabled
  udev rules          Disabled
  Installed tests     Disabled
  GTK examples        Disabled
  Documentation       Disabled

The build directory is `build-538d` inside the source checkout.

The library was installed with:

``` bash
cd ~/src/libfprint-538d
sudo meson install -C build-538d

# Security hardening: ensure custom build directory and binaries cannot be
# tampered with by unprivileged users, preventing LPE via LD_LIBRARY_PATH
sudo chown -R root:root /opt/libfprint-538d
sudo chmod -R 755 /opt/libfprint-538d
```

The custom library was deliberately installed under `/opt`, rather than
replacing the distribution's `/usr/lib` libfprint library.

### How fprintd is made to use this library

The systemd drop-in below sets `LD_LIBRARY_PATH` only for the `fprintd`
service:

**File:** `/etc/systemd/system/fprintd.service.d/20-libfprint-538d.conf`

``` ini
[Service]
Environment="LD_LIBRARY_PATH=/opt/libfprint-538d/lib"
```

This is the key integration step: fprintd loads the custom library from
`/opt`, while the normal system library is not overwritten.

After changing systemd service configuration, reload systemd:

``` bash
sudo systemctl daemon-reload
```

To check which libfprint library the running fprintd process has loaded,
first activate it with a fingerprint command, then inspect its mappings:

``` bash
pid=$(pgrep -xo fprintd)
sudo grep -F 'libfprint-2.so' "/proc/$pid/maps"
```

The expected path contains:

``` text
/opt/libfprint-538d/lib/libfprint-2.so.2.0.0
```

`fprintd` being `inactive (dead)` while idle is normal because it is
D-Bus activated.

## 4. Additional fprintd service drop-ins

Two other drop-ins are present.

### Debug logging (Troubleshooting only)

**File:** `/etc/systemd/system/fprintd.service.d/override.conf`

``` ini
[Service]
Environment=G_MESSAGES_DEBUG=all FP_DEBUG=all
```

This was used during initial troubleshooting to inspect sensor communication.
**Security Note:** In production, remove this file (or comment out the line)
and run `sudo systemctl daemon-reload && sudo systemctl restart fprintd`.
Leaving full debug active produces excessive journal noise and records verbose
low-level biometric/USB protocol telemetry in system logs.

### Stop timeout

**File:** `/etc/systemd/system/fprintd.service.d/10-stop-timeout.conf`

``` ini
# A stale device handle can make fprintd ignore SIGTERM after resume.
# The numeric prefix lets an administrator's override.conf take precedence.
[Service]
TimeoutStopSec=3s
```

This came from Omarchy's default fingerprint integration and helps avoid
a stuck service during restart.

The three drop-ins serve different purposes and should coexist:

``` text
/etc/systemd/system/fprintd.service.d/
├── 10-stop-timeout.conf
├── 20-libfprint-538d.conf
└── override.conf
```

## 5. Fingerprint enrollment and verification

The enrollment was completed using:

``` bash
fprintd-enroll
```

The successful enrollment completed all 16 samples:

``` text
Enrollment stage 16/16 complete
ENROLL_NUM_STATES completed successfully
Enrollment complete with 16 samples
Print for finger FP_FINGER_RIGHT_INDEX enrolled
```

The print was saved under fprintd's storage for user `light`.

Useful commands:

``` bash
# List enrolled fingerprints for the current user
fprintd-list "$USER"

# Verify the enrolled finger
fprintd-verify

# Enroll another finger, if desired
fprintd-enroll
```

The successful verification output was:

``` text
Using device /net/reactivated/Fprint/Device/0
Listing enrolled fingers:
 - #0: right-index-finger
Verify started!
Verifying: right-index-finger
Verify result: verify-match (done)
```

## 6. `sudo` fingerprint authentication

Fingerprint authentication was enabled in:

**File:** `/etc/pam.d/sudo`

The relevant working configuration is:

``` pam
#%PAM-1.0
auth      [success=1 default=ignore] pam_exec.so quiet /usr/bin/omarchy-hw-laptop-closed
auth      sufficient pam_fprintd.so
auth        include     system-auth
account     include     system-auth
session     include     system-auth
session     optional    pam_systemd.so class=none
```

The first PAM rule is an Omarchy laptop-lid check. When the lid is
closed, it skips the following fingerprint module. With the laptop open,
the script returned status `1`, so the fingerprint module was not
skipped.

The `sufficient` fingerprint rule allows a successful fingerprint match
to authenticate. If fingerprint authentication does not succeed, the
stack continues to `system-auth`, preserving password authentication.

**Security Considerations for sudo:**
- Ensure `/usr/bin/omarchy-hw-laptop-closed` is owned by `root:root` with `0755` permissions since it executes in the root security context via `pam_exec.so`.
- Fingerprint `sudo` activates for any process invoking `sudo` in an active session. Always check the terminal prompt before touching the sensor. Over remote SSH sessions, PAM will still prompt for a finger on the physical machine unless scoped to local TTYs.

### Test `sudo`

``` bash
sudo -k
sudo -v
echo "sudo exit status: $?"
```

Expected behavior:

1.  The terminal asks for the enrolled finger.
2.  Place the enrolled right index finger on the sensor.
3.  A successful match validates sudo credentials.
4.  The exit status is `0`.

This exact test succeeded on the machine.

## 7. Omarchy Quickshell lock-screen fingerprint authentication

Omarchy uses its Quickshell lock integration, not a standalone
`hyprlock` PAM configuration.

The Omarchy lock uses two separate PAM service files:

-   `/etc/pam.d/omarchy-lock-password`
-   `/etc/pam.d/omarchy-lock-fingerprint`

The fingerprint PAM file created by Omarchy is:

**File:** `/etc/pam.d/omarchy-lock-fingerprint`

``` pam
#%PAM-1.0
auth       required                    pam_fprintd.so
account    include                     system-local-login
```

The password PAM service remains separate:

**File:** `/etc/pam.d/omarchy-lock-password`

Omarchy manages this file. It should be preserved rather than replaced
with the fingerprint stack.

The Quickshell lock service references both PAM services. The relevant
source is:

-   [`Service.qml` in
    Omarchy](https://github.com/basecamp/omarchy/blob/master/shell/plugins/lock/Service.qml)

The source contains separate references to `omarchy-lock-password` and
`omarchy-lock-fingerprint`.

### How the Omarchy lock integration was applied

The Omarchy script is:

-   [`omarchy-apply-lock`](https://github.com/basecamp/omarchy/blob/master/bin/omarchy-apply-lock)

It detects enrolled fingerprints and configures the fingerprint lock PAM
service and supporting system files.

On this system, the following command was successful:

``` bash
sudo env OMARCHY_PATH=/usr/share/omarchy \
  /usr/share/omarchy/bin/omarchy-apply-lock
```

The explicit `OMARCHY_PATH` is important in this case. Running the
script with `sudo` without passing that environment variable caused it
to look for a source file under `/default/...` and fail.

The successful run printed:

``` text
Configuring lock screen password authentication...
Configuring lock screen fingerprint authentication...
```

### Suspend/resume support

The Omarchy resume hook was installed at:

``` text
/usr/lib/systemd/system-sleep/fprintd-resume
```

It restarts fprintd asynchronously after resume, helping recover from a
stale device handle after suspend.

Source file:

-   [`fprintd-resume`](https://github.com/basecamp/omarchy/blob/master/default/systemd/system-sleep/fprintd-resume)

It was installed with:

``` bash
sudo install -Dm755 \
  /usr/share/omarchy/default/systemd/system-sleep/fprintd-resume \
  /usr/lib/systemd/system-sleep/fprintd-resume
```

The timeout drop-in was installed with:

``` bash
sudo install -Dm644 \
  /usr/share/omarchy/default/systemd/system/fprintd.service.d/10-stop-timeout.conf \
  /etc/systemd/system/fprintd.service.d/10-stop-timeout.conf

sudo systemctl daemon-reload
```

### Lock-screen test result

The Omarchy lock screen was tested after applying the configuration. The
enrolled fingerprint successfully unlocked it.

To test again, use the configured Omarchy lock shortcut or run the lock
command configured by your current Omarchy setup. Keep password
authentication available as a fallback.

## 8. Useful troubleshooting commands

### Check the sensor and enrolled prints

``` bash
fprintd-list "$USER"
fprintd-verify
```

### Check fprintd service state and logs

``` bash
systemctl status fprintd.service
journalctl -u fprintd.service -b --no-pager -n 150
```

Because fprintd is D-Bus activated, an idle service may show
`inactive (dead)`. That alone does not indicate a failure.

### Check the custom library drop-in

``` bash
cat /etc/systemd/system/fprintd.service.d/20-libfprint-538d.conf
```

### Check all fprintd drop-ins

``` bash
systemd-analyze cat-config fprintd.service
```

### Check the lock PAM files

``` bash
cat /etc/pam.d/omarchy-lock-fingerprint
cat /etc/pam.d/omarchy-lock-password
```

### Check the resume hook and timeout file

``` bash
ls -l \
  /usr/lib/systemd/system-sleep/fprintd-resume \
  /etc/systemd/system/fprintd.service.d/10-stop-timeout.conf
```

### Inspect recent fingerprint-related logs

``` bash
journalctl -b --since "5 minutes ago" \
  | grep -Ei 'fprintd|libfprint|fingerprint|pam_fprintd|verify'
```

## 9. Important precautions

1.  **Do not overwrite `/usr/lib`'s system libfprint library** with this
    custom build. The working setup keeps the custom build in
    `/opt/libfprint-538d` and selects it for fprintd using a systemd
    environment override.
2.  **Ensure `/opt/libfprint-538d` has strict `root:root` ownership and `755` permissions.**
    Because `fprintd` runs as root and loads libraries via `LD_LIBRARY_PATH`,
    loose permissions on this directory could allow local privilege escalation.
3.  **Do not run firmware initialization, erase, or reflash commands**
    as routine troubleshooting. The sensor already has a working
    firmware/PSK/TLS state.
4.  **Do not remove the password PAM fallback.** Keep a working password
    route for sudo and the lock screen.
5.  **Disable SDDM autologin.** Leaving autologin enabled bypasses screen
    lock and disk authentication on reboot.
6.  **Disable verbose debug logging (`override.conf`) in production**
    to avoid telemetry leakage and journal bloat once setup is verified.
7.  **Do not run Omarchy's stock fingerprint package setup blindly.**
    Its package-management logic may install or replace libfprint
    packages and interfere with this custom driver.
8.  After changing fprintd drop-ins, run `sudo systemctl daemon-reload`.
9.  Before changing SDDM PAM, keep the current desktop session open
    and ensure you know the account password. A PAM mistake can prevent
    graphical login.

## 10. SDDM login: current state and next step

SDDM autologin has been disabled to ensure physical security (preventing
a reboot from granting unauthenticated desktop access).

The greeter currently authenticates using standard password authentication.
SDDM fingerprint login has **not yet been configured or tested**.

The current SDDM PAM file is `/etc/pam.d/sddm`. Its authentication
section includes `system-login` and optional keyring modules. Do not
assume that the working `sudo` or Quickshell PAM setup automatically
enables SDDM fingerprint login; SDDM needs its own carefully tested PAM
configuration.

When continuing this work:

1.  Back up `/etc/pam.d/sddm`.
2.  Confirm password authentication works at the lock screen and that
    you know the account password.
3.  Add fingerprint authentication to the SDDM PAM stack while retaining
    password fallback. Note that fingerprint login at greeter does not
    automatically unlock PAM keyrings (GNOME Keyring / KWallet), which
    require the plaintext login password.
4.  Keep the current session open and have a TTY recovery route
    available before restarting the display manager.

**Do not treat SDDM fingerprint login as complete until it has been
tested at the actual greeter.**

------------------------------------------------------------------------

## 11. Quick reference: files created or changed

  ----------------------------------------------------------------------------------------------------
  Path                                                             Purpose
  ---------------------------------------------------------------- -----------------------------------
  `/opt/libfprint-538d/lib/libfprint-2.so.2.0.0`                   Custom Goodix-capable libfprint
                                                                   build

  `/etc/systemd/system/fprintd.service.d/20-libfprint-538d.conf`   Makes fprintd load the custom
                                                                   library

  `/etc/systemd/system/fprintd.service.d/override.conf`            Verbose fprintd debug environment

  `/etc/systemd/system/fprintd.service.d/10-stop-timeout.conf`     fprintd stop timeout

  `/etc/pam.d/sudo`                                                sudo fingerprint authentication

  `/etc/pam.d/omarchy-lock-fingerprint`                            Quickshell fingerprint PAM service

  `/etc/pam.d/omarchy-lock-password`                               Quickshell password PAM service

  `/usr/lib/systemd/system-sleep/fprintd-resume`                   Restart fprintd after resume

  `/var/lib/fprint/light/`                                         Enrolled fingerprint data for user
                                                                   `light`
  ----------------------------------------------------------------------------------------------------

**Known-good state:** custom libfprint fork installed under `/opt`,
fprintd using that library, right-index enrollment verified, `sudo`
fingerprint authentication working, and Omarchy Quickshell lock-screen
fingerprint authentication working. SDDM greeter authentication remains
future work.
