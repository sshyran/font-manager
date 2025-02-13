/* DatabaseProxy.vala
 *
 * Copyright (C) 2020-2022 Jerry Casiano
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.
 *
 * If not, see <http://www.gnu.org/licenses/gpl-3.0.txt>.
*/

namespace FontManager {

    public class DatabaseProxy : Object {

        public signal void status_changed ();
        public signal void update_started ();
        public signal void update_complete ();

        int n_db_types = 4;
        GLib.Cancellable? cancellable = null;
        GLib.HashTable <int, bool>? status = null;
        ProgressCallback? progress = null;

        public DatabaseProxy () {
            status = new GLib.HashTable <DatabaseType, bool> (null, null);
            for (int i = 0; i < n_db_types; i++)
                status.insert((DatabaseType) i, false);
            status_changed.connect(() => {
                for (int i = 1; i < n_db_types; i++)
                    if (status[i])
                        continue;
                    else
                        return;
                update_complete();
            });
            try {
                Database main = get_database(DatabaseType.BASE);
                for (int i = 1; i < n_db_types; i++) {
                    try {
                        get_database((DatabaseType) i);
                        main.attach((DatabaseType) i);
                    } catch (Error e) {
                        critical(e.message);
                    }
                }
            } catch (Error e) {
                critical(e.message);
            }
        }

        public bool ready (DatabaseType type) {
            return status[type];
        }

        public void set_cancellable (Cancellable? cancellable) {
            this.cancellable = cancellable;
            return;
        }

        public void set_progress_callback (ProgressCallback? progress) {
            this.progress = progress;
            return;
        }

        public void update (Json.Object available_fonts) {
            update_started();
            var available_files = new StringSet();
            foreach (string path in list_available_font_files())
                available_files.add(path);
            for (int i = 1; i < n_db_types; i++) {
                var type = (DatabaseType) i;
                status.replace(type, false);
                try {
                    var child = get_database(type);
                    update_database.begin(
                        child,
                        type,
                        available_fonts,
                        available_files,
                        progress,
                        cancellable,
                        (obj, res) => {
                            try {
                                status.replace(type, update_database.end(res));
                                Idle.add(() => {
                                    status_changed();
                                    return GLib.Source.REMOVE;
                                });
                            } catch (Error e) {
                                critical(e.message);
                            }
                        }
                    );
                } catch (Error e) {
                    critical(e.message);
                }
            }
            return;
        }

    }

}
