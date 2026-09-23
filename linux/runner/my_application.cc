#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <glib/gstdio.h>
#include <string.h>

#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

// The application icon and the desktop entry are installed in the directories
// freedesktop.org defines for them, relative to the directory the executable runs
// from: `share/icons/hicolor/<size>/apps/<application ID>.png` and
// `share/applications/<application ID>.desktop`. The icon is the image every
// platform uses (see `packages/fpaint_assets/assets/app_icon.png`), shipped in
// its natural size and scaled down by whichever desktop environment displays it.
static const char kShareDirectory[] = "share";
static const char kIconsDirectory[] = "icons";
static const char kIconTheme[] = "hicolor";
static const char kIconThemeSubdirectory[] = "apps";
static const char kIconFileExtension[] = ".png";
static const char kApplicationsDirectory[] = "applications";
static const char kDesktopEntryFileExtension[] = ".desktop";

// The icon theme directory the installed icon sits in. It names the pixel size
// of the bundled image, so it is set in `linux/CMakeLists.txt` beside the install
// rule that copies the image there, and passed to this file as a preprocessor
// definition.
static const char kIconSizeDirectory[] = APPLICATION_ICON_SIZE_DIRECTORY;

// The desktop entry key the runner rewrites before publishing the bundled entry:
// that entry cannot name the executable itself, because a downloaded bundle is
// unzipped wherever its user likes and the path is only known at runtime. The
// path is quoted because a desktop entry splits arguments on white space.
static const char kDesktopEntryExecKey[] = "Exec=";
static const char kDesktopEntryFileArgument[] = " %f";

// Defining this environment variable, to any value, stops the runner from
// publishing a desktop entry for the bundle it runs from. A packager (.deb,
// AppImage, Flatpak, Snap) ships that entry itself and must not have the
// application write one into the user's data directory.
static const char kDesktopIntegrationOptOut[] =
    "FPAINT_SKIP_DESKTOP_INTEGRATION";

// The application ID Linux builds used before it was aligned with the other
// platforms. Flutter's `path_provider` names the application data directory after
// the application ID the running application registered, so the recovery drafts
// and preferences of an installation that ran with the placeholder ID live in a
// directory named after it.
static const char kLegacyApplicationId[] = "com.example.fpaint";

// The kernel exposes the running executable through this symbolic link.
static const char kExecutablePath[] = "/proc/self/exe";

// Permissions of the directories the runner creates inside the user's data
// directory, which belong to that user alone.
static const int kUserDataDirectoryMode = 0700;

// Sizes the application icon is handed to the window manager in. Desktops pick
// the size closest to what they display, and GTK silently drops icons that are
// too large for the windowing system (a lone 512x512 pixbuf never reaches the
// X11 `_NET_WM_ICON` property), so the bundled image is scaled down to the sizes
// desktop environments ask for.
static const int kApplicationIconSizes[] = {16, 32, 48, 64, 128, 256};

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Returns the absolute path of the running executable, or nullptr when it cannot
// be resolved. The bundle directory is derived from it because the Flutter engine
// does not expose the bundle to the runner.
static gchar* my_application_get_executable_path() {
  return g_file_read_link(kExecutablePath, nullptr);
}

// Returns the absolute path of the bundle's share/ directory, which holds the
// installed desktop integration files, or nullptr when the executable cannot be
// resolved (e.g. when the runner is not started from a built bundle).
static gchar* my_application_get_share_directory() {
  g_autofree gchar* executable_path = my_application_get_executable_path();
  if (executable_path == nullptr) {
    return nullptr;
  }
  g_autofree gchar* bundle_directory = g_path_get_dirname(executable_path);
  return g_build_filename(bundle_directory, kShareDirectory, nullptr);
}

// Returns the file name of the application icon: the application ID, which is
// also the icon name the desktop entry refers to.
static gchar* my_application_get_icon_file_name() {
  return g_strconcat(APPLICATION_ID, kIconFileExtension, nullptr);
}

// Returns the file name of the application's desktop entry: the application ID,
// which is what a desktop environment matches a window against.
static gchar* my_application_get_desktop_entry_file_name() {
  return g_strconcat(APPLICATION_ID, kDesktopEntryFileExtension, nullptr);
}

// Returns the absolute path of the icon installed with the bundle, or nullptr
// when the bundle cannot be located.
static gchar* my_application_get_bundled_icon_path() {
  g_autofree gchar* share_directory = my_application_get_share_directory();
  if (share_directory == nullptr) {
    return nullptr;
  }
  g_autofree gchar* file_name = my_application_get_icon_file_name();
  return g_build_filename(share_directory, kIconsDirectory, kIconTheme,
                          kIconSizeDirectory, kIconThemeSubdirectory, file_name,
                          nullptr);
}

// Returns the absolute path of the desktop entry installed with the bundle, or
// nullptr when the bundle cannot be located.
static gchar* my_application_get_bundled_desktop_entry_path() {
  g_autofree gchar* share_directory = my_application_get_share_directory();
  if (share_directory == nullptr) {
    return nullptr;
  }
  g_autofree gchar* file_name = my_application_get_desktop_entry_file_name();
  return g_build_filename(share_directory, kApplicationsDirectory, file_name,
                          nullptr);
}

// Returns the absolute path of the desktop entry the runner publishes in the
// user's data directory, or nullptr when that directory cannot be determined.
static gchar* my_application_get_user_desktop_entry_path() {
  const gchar* user_data_directory = g_get_user_data_dir();
  if (user_data_directory == nullptr) {
    return nullptr;
  }
  g_autofree gchar* file_name = my_application_get_desktop_entry_file_name();
  return g_build_filename(user_data_directory, kApplicationsDirectory, file_name,
                          nullptr);
}

// Returns the absolute path the icon is published at in the user's data
// directory, which desktop environments look icons up in, or nullptr when that
// directory cannot be determined.
static gchar* my_application_get_user_icon_path() {
  const gchar* user_data_directory = g_get_user_data_dir();
  if (user_data_directory == nullptr) {
    return nullptr;
  }
  g_autofree gchar* file_name = my_application_get_icon_file_name();
  return g_build_filename(user_data_directory, kIconsDirectory, kIconTheme,
                          kIconSizeDirectory, kIconThemeSubdirectory, file_name,
                          nullptr);
}

// Returns TRUE when a desktop entry for this application is installed in one of
// the system's data directories. An entry a distribution or a packager installed
// describes the application and its bundle better than one written from inside
// the bundle, so the runner leaves that one in charge.
static gboolean my_application_system_has_desktop_entry() {
  const gchar* const* system_data_directories = g_get_system_data_dirs();
  g_autofree gchar* file_name = my_application_get_desktop_entry_file_name();
  for (guint i = 0; system_data_directories[i] != nullptr; i++) {
    g_autofree gchar* path =
        g_build_filename(system_data_directories[i], kApplicationsDirectory,
                         file_name, nullptr);
    if (g_file_test(path, G_FILE_TEST_IS_REGULAR)) {
      return TRUE;
    }
  }
  return FALSE;
}

// Writes `length` bytes of `contents` to `path`, creating the parent directories
// when they do not exist yet, and returns whether the file is in place
// afterwards. A file that already holds exactly those bytes is left alone:
// rewriting it would only bump its modification time and make desktop
// environments reload their caches for nothing.
static gboolean my_application_write_file_if_changed(const gchar* path,
                                                     const gchar* contents,
                                                     gssize length) {
  g_autofree gchar* existing_contents = nullptr;
  gsize existing_length = 0;
  if (g_file_get_contents(path, &existing_contents, &existing_length, nullptr) &&
      existing_length == (gsize)length &&
      memcmp(existing_contents, contents, (gsize)length) == 0) {
    return TRUE;
  }

  g_autofree gchar* directory = g_path_get_dirname(path);
  if (g_mkdir_with_parents(directory, kUserDataDirectoryMode) != 0) {
    g_warning("Unable to create %s", directory);
    return FALSE;
  }

  g_autoptr(GError) error = nullptr;
  if (!g_file_set_contents(path, contents, length, &error)) {
    g_warning("Unable to write %s: %s", path,
              error != nullptr ? error->message : "unknown error");
    return FALSE;
  }
  return TRUE;
}

// Returns the bundled desktop entry with its `Exec` key pointing at the
// executable that is running, so that the published copy starts the bundle it
// belongs to instead of relying on an `fpaint` on the PATH.
static gchar* my_application_patch_desktop_entry(
    const gchar* entry, const gchar* executable_path) {
  g_auto(GStrv) lines = g_strsplit(entry, "\n", -1);
  GString* patched_entry = g_string_new(nullptr);
  for (guint i = 0; lines[i] != nullptr; i++) {
    if (i > 0) {
      g_string_append_c(patched_entry, '\n');
    }
    if (g_str_has_prefix(lines[i], kDesktopEntryExecKey)) {
      g_string_append_printf(patched_entry, "%s\"%s\"%s", kDesktopEntryExecKey,
                             executable_path, kDesktopEntryFileArgument);
    } else {
      g_string_append(patched_entry, lines[i]);
    }
  }
  return g_string_free(patched_entry, FALSE);
}

// Copies the bundled application icon into the user's icon theme, unless the same
// image is already there.
static void my_application_publish_icon() {
  g_autofree gchar* source_path = my_application_get_bundled_icon_path();
  g_autofree gchar* target_path = my_application_get_user_icon_path();
  if (source_path == nullptr || target_path == nullptr) {
    return;
  }

  g_autofree gchar* contents = nullptr;
  gsize length = 0;
  if (!g_file_get_contents(source_path, &contents, &length, nullptr)) {
    g_warning("Application icon not found: %s", source_path);
    return;
  }
  my_application_write_file_if_changed(target_path, contents, (gssize)length);
}

// Moves the data directory of an installation that ran with the previous
// application ID to the directory this build uses, which keeps its recovery
// drafts and preferences in place instead of orphaning them. The move happens
// only while the new directory does not exist, so it is a one-time event, and
// only on Linux, where the directory name follows the application ID.
static void my_application_migrate_legacy_data_directory() {
  const gchar* user_data_directory = g_get_user_data_dir();
  if (user_data_directory == nullptr) {
    return;
  }
  g_autofree gchar* current_directory =
      g_build_filename(user_data_directory, APPLICATION_ID, nullptr);
  g_autofree gchar* legacy_directory =
      g_build_filename(user_data_directory, kLegacyApplicationId, nullptr);
  if (g_file_test(current_directory, G_FILE_TEST_EXISTS) ||
      !g_file_test(legacy_directory, G_FILE_TEST_EXISTS)) {
    return;
  }
  if (g_rename(legacy_directory, current_directory) != 0) {
    g_warning("Unable to move %s to %s", legacy_directory, current_directory);
  }
}

// Publishes a desktop entry and an icon for the bundle the application runs from,
// which is what gives its windows a name and an icon in the task bar, the window
// switcher and the window frame.
//
// A Wayland application cannot set its own window icon - GTK's
// gtk_window_set_icon_list() is a no-op there - and compositors take both the
// icon and the name from the desktop entry whose file name equals the window's
// application ID. A system installation provides that entry in
// `share/applications`; a downloaded bundle is just a directory in the user's
// home, so the application publishes the entry the bundle carries in the user's
// data directory the first time it runs, aimed back at the directory it is
// running from. The entry is refreshed whenever the bundle moves, is never
// written when a system entry exists, and never written at all when
// kDesktopIntegrationOptOut is set.
static void my_application_publish_desktop_entry() {
  if (g_getenv(kDesktopIntegrationOptOut) != nullptr) {
    return;
  }
  if (my_application_system_has_desktop_entry()) {
    return;
  }

  g_autofree gchar* bundled_entry_path =
      my_application_get_bundled_desktop_entry_path();
  g_autofree gchar* bundled_entry = nullptr;
  if (bundled_entry_path == nullptr ||
      !g_file_get_contents(bundled_entry_path, &bundled_entry, nullptr,
                           nullptr)) {
    // Running from something that carries no desktop entry, such as the unbundled
    // build output: there is nothing to publish.
    return;
  }

  g_autofree gchar* executable_path = my_application_get_executable_path();
  g_autofree gchar* entry =
      executable_path != nullptr
          ? my_application_patch_desktop_entry(bundled_entry, executable_path)
          : g_strdup(bundled_entry);

  g_autofree gchar* user_entry_path =
      my_application_get_user_desktop_entry_path();
  if (user_entry_path == nullptr) {
    return;
  }
  if (my_application_write_file_if_changed(user_entry_path, entry,
                                           (gssize)strlen(entry))) {
    my_application_publish_icon();
  }
}

// Sets the window icon shown by the window manager, the task bar and window
// switchers. On X11 this is what fills in the `_NET_WM_ICON` property; without it
// desktops fall back to a generic icon (KDE displays its X logo). Wayland has no
// per-window icon, where the desktop entry published above is what desktops read
// instead. The window must be realized, as GTK forwards the icon to the windowing
// system through the GDK window.
static void my_application_set_window_icon(GtkWindow* window) {
  g_autofree gchar* icon_path = my_application_get_bundled_icon_path();
  if (icon_path == nullptr) {
    g_warning("Unable to locate the application icon");
    return;
  }
  if (!g_file_test(icon_path, G_FILE_TEST_IS_REGULAR)) {
    g_warning("Application icon not found: %s", icon_path);
    return;
  }

  g_autoptr(GError) error = nullptr;
  g_autoptr(GdkPixbuf) source = gdk_pixbuf_new_from_file(icon_path, &error);
  if (source == nullptr) {
    g_warning("Unable to load the application icon from %s: %s", icon_path,
              error != nullptr ? error->message : "unknown error");
    return;
  }

  GList* icons = nullptr;
  for (guint i = 0; i < G_N_ELEMENTS(kApplicationIconSizes); i++) {
    const int size = kApplicationIconSizes[i];
    GdkPixbuf* icon =
        gdk_pixbuf_scale_simple(source, size, size, GDK_INTERP_BILINEAR);
    if (icon == nullptr) {
      g_warning("Unable to scale the application icon to %d pixels", size);
      continue;
    }
    icons = g_list_append(icons, icon);
  }
  if (icons == nullptr) {
    g_warning("Unable to prepare the application icon");
    return;
  }

  // GtkWindow references the pixbufs and copies the list.
  gtk_window_set_icon_list(window, icons);
  g_list_free_full(icons, g_object_unref);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);

  // Both of these run before the engine starts the Dart code that reads the
  // application data directory, and before the window is mapped. The migration
  // moves the recovery drafts and preferences of an installation that ran with
  // the previous application ID to the directory this build uses, and the desktop
  // entry is what a desktop environment reads the icon and the name of a window
  // from while that window is created, so an entry published later would only
  // apply to it after a remap.
  my_application_migrate_legacy_data_directory();
  my_application_publish_desktop_entry();

  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "fpaint");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "fpaint");
  }

  gtk_window_set_default_size(window, 1280, 720);

  // Realize the window before applying the icon: GTK only forwards the icon list
  // to the windowing system once the window owns a GDK window. Applying it here,
  // before the window is shown, means window managers have the icon in the very
  // first frame they see.
  gtk_widget_realize(GTK_WIDGET(window));
  my_application_set_window_icon(window);

  gtk_widget_show(GTK_WIDGET(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
