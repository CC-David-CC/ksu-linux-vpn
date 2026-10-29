const Gio = imports.gi.Gio;
const GLib = imports.gi.GLib;
let selectedRule;
var polkit = {Result: {YES: 'yes'}, addRule: (rule) => { selectedRule = rule; }};
const bytes = Gio.File.new_for_path('desktop/60-codiserver-network.rules').load_contents(null)[1];
eval(new TextDecoder().decode(bytes));
function check(condition, description) { if (!condition) throw new Error(description); }
const active = {local: true, active: true};
for (const id of ['network-control', 'enable-disable-network', 'enable-disable-wifi', 'wifi.scan', 'settings.modify.own'])
  check(selectedRule({id: 'org.freedesktop.NetworkManager.' + id}, active) === 'yes', id);
for (const subject of [{local: false, active: true}, {local: true, active: false}])
  check(selectedRule({id: 'org.freedesktop.NetworkManager.network-control'}, subject) === undefined, 'inactive or remote denied');
for (const id of ['org.freedesktop.NetworkManager.settings.modify.system', 'org.freedesktop.policykit.exec', 'org.freedesktop.NetworkManager.settings.modify.global-dns'])
  check(selectedRule({id}, active) === undefined, 'unrelated action not granted');
print('network policy checks passed');
