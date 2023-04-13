namespace EinkFriendlyLauncher {
	const int NEXT_PREV_WEIGHT = 4;
	const int PADDING = 12;
	const int TOUCH_HEIGHT = 128;
	const int MINIMUM_ENTRIES = 1;
	const string APP_ID = "com.samueldr.EinkFriendlyLauncher";

	[DBus (name="com.samueldr.EinkFriendlyLauncher")]
	class ApplicationService : Object {
		private static GLib.Once<ApplicationService> _instance;
		public static unowned ApplicationService instance {
			get { return _instance.once(() => { return new ApplicationService(); }); }
		}

		public void show() {
			ApplicationState.instance.show();
		}
	}

	class ApplicationData : Object {
		public AppInfo info { get; set; }
		public string id { get { return info.get_id(); } }
		public string name { get { return info.get_display_name(); } }
		public string exec { get { return info.get_executable(); } }

		public bool favorite {
			get {
				return ApplicationState.instance.favorites.contains(id);
			}
		}

		public void toggle_favorite() {
			ApplicationState.instance.toggle_favorite(id);
		}

		public bool is_shown {
			get { return info.should_show(); }
		}

		public static int cmp(ApplicationData a, ApplicationData b) {
			if (a.favorite && !b.favorite) {
				return -1;
			}
			else if (!a.favorite && b.favorite) {
				return 1;
			}
			return strcmp(a.name, b.name);
		}

		public void launch() {
#if DONT_SPAWN_PROCESSES
			var parsed_exec = /%./.replace(exec, exec.length, 0, "").strip();
			debug("Would be launching %s (%s)", name, parsed_exec);
			debug("  desktop file ID: %s", id);
			ApplicationState.instance.launched();
			return;
#endif
			info.launch(null, null);
			ApplicationState.instance.launched();
		}

		public static ApplicationData from_appinfo(AppInfo info) {
			var data = new ApplicationData();
			data.info = info;

			return data;
		}
	}

	class ApplicationState : Object {
		private static GLib.Once<ApplicationState> _instance;
		public static unowned ApplicationState instance {
			get { return _instance.once(() => { return new ApplicationState(); }); }
		}

		public int height { get; set; default = 0; }
		public int current_page { get; set; default = 0; }
		public int per_page { get; set; default = 1; }
		public Gee.ArrayList<ApplicationData> applications { get; set; default = new Gee.ArrayList<ApplicationData>(); }
		public int total_pages {
			get {
				return (int)Math.ceil((double)applications.size/per_page) - 1;
			}
		}
		public Gee.Set<string> favorites {
			get; set; default = new Gee.HashSet<string>();
		}

		public signal void launched();
		public signal void show();
		public signal void resize();
		public signal void need_refresh();
		public signal void refresh_applications();

		public ApplicationState() {
			notify["current-page"].connect(() => {
				need_refresh();
			});
			notify["height"].connect(() => {
				resize();
			});
			refresh_applications.connect(() => {
				_refresh_applications();
			});
			need_refresh.connect(() => {
				_sort_applications();
			});

			load_userdata();
		}

		public void set_page(int amount, bool relative) {
			if (relative) {
				current_page += amount;
			}
			else {
				current_page = amount;
			}

			if (current_page < 0) {
				current_page = 0;
			}
			if (current_page >= total_pages) {
				current_page = (int)total_pages;
			}
		}

		private void _refresh_applications() {
			applications.clear();
			foreach (var app in AppInfo.get_all()) {
				if (app.should_show()) {
					applications.add(ApplicationData.from_appinfo(app));
				}
			}
			_sort_applications();
			set_page(0, false);
		}

		private void _sort_applications() {
			applications.sort(ApplicationData.cmp);
		}

		public void toggle_favorite(string id) {
			if (favorites.contains(id)) {
				favorites.remove(id);
			}
			else {
				favorites.add(id);
			}
			ApplicationState.instance.save_userdata();
		}

		public void load_userdata() {
			favorites.clear();

			FileStream stream = FileStream.open(Path.build_filename(config_dir(), "favorites.list"), "r");
			if (stream != null) {
				string? line = null;
				while ((line = stream.read_line()) != null) {
					favorites.add(line.strip());
				}
			}
		}

		public void save_userdata() {
			var dir = File.new_for_path(config_dir());
			if (!dir.query_exists()) {
				dir.make_directory_with_parents();
			}
			FileStream stream = FileStream.open(Path.build_filename(config_dir(), "favorites.list"), "w");
			if (stream != null) {
				foreach (var app in favorites) {
					stream.puts(app);
					stream.putc('\n');
				}
			}
			else {
				error("Could not open favorites.list for writing");
			}
		}

		private string config_dir() {
			return Path.build_filename(Environment.get_user_config_dir(), APP_ID);
		}
	}

	class ApplicationEntry : Gtk.Button {
		public ApplicationData app { get; construct; }
		public ApplicationEntry(ApplicationData app) {
			Object(
				app: app
			);
		}
		construct {
			halign = Gtk.Align.FILL;
			valign = Gtk.Align.FILL;
			height_request = TOUCH_HEIGHT;
			has_frame = false;

			var layout = new Gtk.Box(Gtk.Orientation.HORIZONTAL, PADDING);
			layout.hexpand = true;
			var image = new Gtk.Image.from_icon_name(app.info.get_icon().to_string());
			image.pixel_size = TOUCH_HEIGHT - TOUCH_HEIGHT/4;
			layout.append(image);

			var label = new Gtk.Label(app.name);
			label.halign = Gtk.Align.START;
			label.hexpand = true;
			layout.append(label);

			var star = new Gtk.Image.from_icon_name("favorite");
			star.pixel_size = image.pixel_size / 2;
			layout.append(star);

			if (!app.favorite) {
				star.hide();
			}

			child = layout;

			bool long_pressed = false;

			clicked.connect(() => {
				if (!long_pressed) {
					app.launch();
				}
				long_pressed = false;
			});

			var long_press = new Gtk.GestureLongPress();
			long_press.pressed.connect(() => {
				long_pressed = true;
				app.toggle_favorite();
				ApplicationState.instance.need_refresh();
			});
			add_controller(long_press);
		}
	}

	class ApplicationsList : Gtk.Box {
		public ApplicationsList() {
			Object(
				orientation: Gtk.Orientation.VERTICAL,
				spacing: PADDING
			);
		}
		construct {
			overflow = Gtk.Overflow.HIDDEN;
			halign = Gtk.Align.FILL;
			valign = Gtk.Align.FILL;
			margin_top = PADDING;
			margin_bottom = PADDING;
			margin_start = PADDING;
			margin_end = PADDING;
			vexpand = true;

			refresh();

			ApplicationState.instance.need_refresh.connect(() => {
				refresh();
			});

			ApplicationState.instance.resize.connect(() => {
				handle_resize();
			});
		}
		private void clear() {
			Gtk.Widget child;
			while ((child = get_first_child()) != null) {
				remove(child);
			}
		}
		private void refresh() {
			clear();

			var current_page = ApplicationState.instance.current_page;
			var per_page = ApplicationState.instance.per_page;
			ApplicationState.instance.applications.slice(
				current_page * per_page,
				int.min((current_page+1) * per_page, ApplicationState.instance.applications.size)
			).foreach(
				(app) => {
					append(new ApplicationEntry(app));

					return true;
				}
			);
			queue_draw();
		}

		public void handle_resize() {
			// Remove 2*PADDING to fit more when it's barely fitting.
			var num = ApplicationState.instance.height - PADDING*-2;
			num = num / (TOUCH_HEIGHT+PADDING);
			ApplicationState.instance.per_page = int.max(MINIMUM_ENTRIES, num);
			ApplicationState.instance.need_refresh();
		}
	}

	class NavBar : Gtk.Grid {
		private Gtk.Button prev { get; set; }
		private Gtk.Button next { get; set; }
		private Gtk.Button pager { get; set; }

		construct {
			halign = Gtk.Align.FILL;
			valign = Gtk.Align.END;
			column_homogeneous = true;
			margin_bottom = PADDING;
			margin_start = PADDING;
			margin_end = PADDING;

			pager = new Gtk.Button.with_label("...");
			pager.has_frame = false;
			pager.height_request = TOUCH_HEIGHT;
			attach(pager, NEXT_PREV_WEIGHT+1, 1);

			prev = new Gtk.Button.with_label("Previous");
			attach(prev, 1, 1);

			next = new Gtk.Button.with_label("Next");
			attach(next, NEXT_PREV_WEIGHT+2, 1);

			((Gtk.GridLayoutChild) get_layout_manager()
				.get_layout_child(prev))
				.column_span = NEXT_PREV_WEIGHT
			;
			((Gtk.GridLayoutChild) get_layout_manager()
				.get_layout_child(next))
				.column_span = NEXT_PREV_WEIGHT
			;

			prev.clicked.connect(() => {
				ApplicationState.instance.set_page(-1, true);
			});
			next.clicked.connect(() => {
				ApplicationState.instance.set_page(1, true);
			});
			pager.clicked.connect(() => {
			});

			refresh();

			ApplicationState.instance.need_refresh.connect(() => {
				refresh();
			});
		}

		private void refresh() {
			Gtk.Label label = (Gtk.Label)pager.child;
			label.label = "%d / %d".printf(ApplicationState.instance.current_page+1, ApplicationState.instance.total_pages+1);
		}
	}

	class MainLayout : Gtk.Box {
		public ApplicationsList apps { get; construct; }
		public NavBar navigation { get; construct; }

		public MainLayout() {
			Object(
				orientation: Gtk.Orientation.VERTICAL,
				spacing: 0
			);
		}

		construct {
			halign = Gtk.Align.FILL;
			valign = Gtk.Align.FILL;

			apps = new ApplicationsList();

			var overlay = new Gtk.Overlay(){
				vexpand = true,
				halign = Gtk.Align.FILL,
				valign = Gtk.Align.FILL
			};
			append(overlay);

			// This widget snitches on resize events.
			var size_oracle = new Gtk.DrawingArea(){
				vexpand = true,
				halign = Gtk.Align.FILL,
				valign = Gtk.Align.FILL
			};
			size_oracle.height_request = MINIMUM_ENTRIES * (TOUCH_HEIGHT+PADDING);
			// And is the main child of the overlay...
			overlay.set_child(size_oracle);
			size_oracle.resize.connect(() => {
				ApplicationState.instance.height = size_oracle.get_height();
			});

			// Since we actually want the Gtk widgets for apps,
			// let's draw ours on top!
			overlay.add_overlay(apps);

			// Don't forget the navigation.
			navigation = new NavBar();
			append(navigation);
		}
	}

	class Application : Gtk.Application {
		public Application() {
			Object(
				application_id: APP_ID,
				flags: ApplicationFlags.FLAGS_NONE
			);
		}

		protected override void activate() {
			var window = new Gtk.ApplicationWindow(this);
			window.hide_on_close = true;
			window.child = new MainLayout();
			window.halign = Gtk.Align.FILL;
			window.valign = Gtk.Align.FILL;

			ApplicationState.instance.launched.connect(() => {
				window.close();
			});

			ApplicationState.instance.show.connect(() => {
				window.show();
			});

			window.maximize();
			window.present();
		}

		public override bool dbus_register(DBusConnection connection, string object_path) throws Error {
			base.dbus_register(connection, object_path);

			try {
				connection.register_object(
					"/%s".printf(APP_ID.replace(".", "/")),
					ApplicationService.instance
				);
			} catch (Error e) {
				error(e.message);
			}

			return true;
		}


		public static int main(string[] args) {
			ApplicationState.instance.refresh_applications();

			var app = new Application();
			app.run(args);

			return 0;
		}
	}
}
