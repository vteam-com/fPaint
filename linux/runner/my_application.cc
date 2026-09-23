#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

// Location of the application icon inside the built bundle, relative to the
// executable. The icon is the same Flutter asset every platform uses
// (see `packages/fpaint_assets/assets/app_icon.png`), so the Linux runner does
// not need a second copy of the image.
static const char kApplicationIconAssetPath[] =
    "data/flutter_assets/packages/fpaint_assets/assets/app_icon.png";

// The kernel exposes the running executable through this symbolic link.
static const char kExecutablePath[] = "/proc/self/exe";

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

// Returns the absolute path of the bundled application icon, or nullptr when it
// cannot be resolved (e.g. when the runner is not started from a built bundle).
// The bundle directory is derived from the executable because the Flutter engine
// does not expose it to the runner.
static gchar* my_application_find_icon_path() {
  g_autofree gchar* executable_path = g_file_read_link(kExecutablePath, nullptr);
  if (executable_path == nullptr) {
    return nullptr;
  }
  g_autofree gchar* bundle_directory = g_path_get_dirname(executable_path);
  return g_build_filename(bundle_directory, kApplicationIconAssetPath, nullptr);
}

// Sets the window icon shown by the window manager, the task bar and window
// switchers. On X11 this is what fills in the `_NET_WM_ICON` property; without
// it desktops fall back to a generic icon (KDE displays its X logo). The window
// must be realized, as GTK forwards the icon to the windowing system through the
// GDK window.
static void my_application_set_window_icon(GtkWindow* window) {
  g_autofree gchar* icon_path = my_application_find_icon_path();
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
