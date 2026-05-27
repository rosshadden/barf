module gio

#pkgconfig gio-2.0

#include <gio/gio.h>

pub struct C.GDBusConnection {}

pub struct C.GVariant {}

pub struct C.GDBusMethodInvocation {}

pub struct C.GDBusInterfaceInfo {}

pub struct C.GError {}

pub const g_bus_type_session = 2
pub const g_dbus_call_flags_none = 0
pub const g_dbus_signal_flags_none = 0

// Session bus
pub fn C.g_bus_get_sync(bus_type int, cancellable voidptr, error_ voidptr) voidptr

// D-Bus connection
pub fn C.g_dbus_connection_call_sync(connection voidptr, bus_name &char, object_path &char, interface_name &char, method_name &char, parameters voidptr, reply_type voidptr, flags int, timeout_msec int, cancellable voidptr, error_ voidptr) voidptr
pub fn C.g_dbus_connection_emit_signal(connection voidptr, destination_bus_name voidptr, object_path &char, interface_name &char, signal_name &char, parameters voidptr, error_ voidptr) int
pub fn C.g_dbus_connection_signal_subscribe(connection voidptr, sender voidptr, interface_name &char, member voidptr, object_path voidptr, arg0 voidptr, flags int, callback voidptr, user_data voidptr, user_data_free_func voidptr) u32
pub fn C.g_dbus_connection_register_object(connection voidptr, object_path &char, interface_info voidptr, vtable voidptr, user_data voidptr, user_data_free_func voidptr, error_ voidptr) u32
pub fn C.g_dbus_connection_get_unique_name(connection voidptr) &char

// D-Bus method invocation reply
pub fn C.g_dbus_method_invocation_return_value(invocation voidptr, parameters voidptr)

// GVariant
pub fn C.g_variant_get_child_value(value voidptr, index_ usize) voidptr
pub fn C.g_variant_get_string(value voidptr, length voidptr) &char
pub fn C.g_variant_get_boolean(value voidptr) int
pub fn C.g_variant_get_int32(value voidptr) i32
pub fn C.g_variant_get_uint32(value voidptr) u32
pub fn C.g_variant_n_children(value voidptr) usize
pub fn C.g_variant_lookup_value(dictionary voidptr, key &char, expected_type voidptr) voidptr
pub fn C.g_variant_new_string(string_ &char) voidptr
pub fn C.g_variant_new_boolean(value int) voidptr
pub fn C.g_variant_new_int32(value i32) voidptr
pub fn C.g_variant_new_uint32(value u32) voidptr
pub fn C.g_variant_new_strv(strv voidptr, length i64) voidptr
pub fn C.g_variant_new_tuple(children voidptr, n_children usize) voidptr
pub fn C.g_variant_unref(value voidptr)
pub fn C.g_variant_is_of_type(value voidptr, type_ &char) int
