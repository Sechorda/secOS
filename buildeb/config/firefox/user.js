// Disable default browser check
user_pref("browser.shell.checkDefaultBrowser", false);

// Disable welcome page
user_pref("browser.startup.homepage_override.mstone", "ignore");

// Set new tab page to blank
user_pref("browser.newtabpage.enabled", false);
user_pref("browser.newtab.url", "about:blank");

// Disable Firefox Accounts and Sync
user_pref("identity.fxaccounts.enabled", false);

// Disable Pocket
user_pref("extensions.pocket.enabled", false);

// Disable telemetry
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.unified", false);

// bookmarks
user_pref("browser.bookmarks.file", "bookmarks.html");
user_pref("browser.bookmarks.autoExportHTML", true);

// Prevent extensions from opening a new tab to their information page
user_pref("extensions.postDownloadThirdPartyPrompt", false);
user_pref("extensions.htmlaboutaddons.recommendations.enabled", false);
user_pref("extensions.getAddons.discovery.api_url", "");

