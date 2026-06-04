#pragma once
#include <gio/gio.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <gtk/gtk.h>
#include <cairo/cairo.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>

/*
 * Singleton state pointer — stored in this translation unit's static storage.
 * systray.v is the only file that includes this header, so there is exactly
 * one copy of barf_sni_state per build.
 */
static void *barf_sni_state = NULL;
static inline void *barf_sni_get(void)       { return barf_sni_state; }
static inline void  barf_sni_set(void *p)    { barf_sni_state = p; }

// Forward declarations for V-exported callbacks (defined in systray.v with @[export]).
// Uses void* and char* to match what V generates for voidptr and &char params.
extern void   barf_systray_method_call(void *conn, char *sender, char *obj_path,
                                       char *iface, char *method, void *params,
                                       void *invocation, void *user_data);
extern void  *barf_systray_get_property(void *conn, char *sender, char *obj_path,
                                        char *iface, char *prop, void *error,
                                        void *user_data);

/* Returns pointer to the static GDBusInterfaceVTable for the watcher object. */
static inline const GDBusInterfaceVTable *barf_systray_vtable(void) {
	static const GDBusInterfaceVTable tbl = {
		(GDBusInterfaceMethodCallFunc)barf_systray_method_call,
		(GDBusInterfaceGetPropertyFunc)barf_systray_get_property,
		NULL,
	};
	return &tbl;
}

/* Introspection XML for org.kde.StatusNotifierWatcher */
static const gchar barf_watcher_xml[] =
	"<node>"
	"  <interface name='org.kde.StatusNotifierWatcher'>"
	"    <method name='RegisterStatusNotifierItem'>"
	"      <arg name='service' direction='in' type='s'/>"
	"    </method>"
	"    <method name='RegisterStatusNotifierHost'>"
	"      <arg name='service' direction='in' type='s'/>"
	"    </method>"
	"    <signal name='StatusNotifierItemRegistered'>"
	"      <arg name='service' type='s'/>"
	"    </signal>"
	"    <signal name='StatusNotifierItemUnregistered'>"
	"      <arg name='service' type='s'/>"
	"    </signal>"
	"    <signal name='StatusNotifierHostRegistered'/>"
	"    <property name='RegisteredStatusNotifierItems' type='as' access='read'/>"
	"    <property name='IsStatusNotifierHostRegistered' type='b' access='read'/>"
	"    <property name='ProtocolVersion' type='i' access='read'/>"
	"  </interface>"
	"</node>";

/* Parses the XML once and returns the cached GDBusInterfaceInfo *. */
static inline GDBusInterfaceInfo *barf_get_watcher_interface(void) {
	static GDBusInterfaceInfo *iface = NULL;
	if (!iface) {
		GDBusNodeInfo *node = g_dbus_node_info_new_for_xml(barf_watcher_xml, NULL);
		if (node) {
			iface = g_dbus_node_info_lookup_interface(node, "org.kde.StatusNotifierWatcher");
			if (iface)
				g_dbus_interface_info_ref(iface);
			g_dbus_node_info_unref(node);
		}
	}
	return iface;
}

/* GVariant tuple helpers */

static inline GVariant *barf_v_s_tuple(const gchar *s) {
	GVariant *c[1] = { g_variant_new_string(s) };
	return g_variant_new_tuple(c, 1);
}

static inline GVariant *barf_v_su_tuple(const gchar *s, guint32 u) {
	GVariant *c[2] = { g_variant_new_string(s), g_variant_new_uint32(u) };
	return g_variant_new_tuple(c, 2);
}

static inline GVariant *barf_v_ss_tuple(const gchar *s1, const gchar *s2) {
	GVariant *c[2] = { g_variant_new_string(s1), g_variant_new_string(s2) };
	return g_variant_new_tuple(c, 2);
}

static inline GVariant *barf_v_ii_tuple(gint32 x, gint32 y) {
	GVariant *c[2] = { g_variant_new_int32(x), g_variant_new_int32(y) };
	return g_variant_new_tuple(c, 2);
}

/* Convert SNI ARGB32 big-endian pixel data to a GdkPixbuf (RGBA). */
static inline GdkPixbuf *barf_argb_to_pixbuf(const guint8 *data, gint w, gint h) {
	GdkPixbuf *pb = gdk_pixbuf_new(GDK_COLORSPACE_RGB, TRUE, 8, w, h);
	if (!pb) return NULL;
	gint   rs = gdk_pixbuf_get_rowstride(pb);
	guchar *px = gdk_pixbuf_get_pixels(pb);
	for (gint y = 0; y < h; y++) {
		for (gint x = 0; x < w; x++) {
			const guint8 *src = data + (y * w + x) * 4;
			guchar       *dst = px + y * rs + x * 4;
			dst[0] = src[1]; /* R */
			dst[1] = src[2]; /* G */
			dst[2] = src[3]; /* B */
			dst[3] = src[0]; /* A */
		}
	}
	return pb;
}

/*
 * Pick the best-fit frame from an a(iiay) IconPixmap GVariant and
 * return a GdkPixbuf scaled to target_size, or NULL.
 */
static inline GdkPixbuf *barf_parse_icon_pixmap(GVariant *pixmap_v, gint target_size) {
	if (!pixmap_v) return NULL;
	gsize n = g_variant_n_children(pixmap_v);
	if (n == 0) return NULL;

	gsize best      = 0;
	gint  best_diff = G_MAXINT;
	for (gsize i = 0; i < n; i++) {
		GVariant *frame = g_variant_get_child_value(pixmap_v, i);
		GVariant *wv    = g_variant_get_child_value(frame, 0);
		gint diff = abs(g_variant_get_int32(wv) - target_size);
		g_variant_unref(wv);
		g_variant_unref(frame);
		if (diff < best_diff) { best_diff = diff; best = i; }
	}

	GVariant       *frame    = g_variant_get_child_value(pixmap_v, best);
	GVariant       *wv       = g_variant_get_child_value(frame, 0);
	GVariant       *hv       = g_variant_get_child_value(frame, 1);
	GVariant       *dv       = g_variant_get_child_value(frame, 2);
	gint            w        = g_variant_get_int32(wv);
	gint            h        = g_variant_get_int32(hv);
	gsize           data_len = 0;
	const guint8   *raw      = (const guint8 *)g_variant_get_fixed_array(dv, &data_len, 1);

	GdkPixbuf *pb = NULL;
	if (raw && (gsize)(w * h * 4) <= data_len) {
		pb = barf_argb_to_pixbuf(raw, w, h);
		if (pb && w != target_size) {
			GdkPixbuf *sc = gdk_pixbuf_scale_simple(pb, target_size, target_size,
			                                         GDK_INTERP_BILINEAR);
			g_object_unref(pb);
			pb = sc;
		}
	}
	g_variant_unref(wv);
	g_variant_unref(hv);
	g_variant_unref(dv);
	g_variant_unref(frame);
	return pb;
}

/*
 * Load a PNG file via Cairo's built-in libpng support, bypassing GDK pixbuf
 * loaders entirely (avoids the broken glycin/bwrap loader on this system).
 * Returns a GdkPixbuf scaled to target_size, or NULL on failure.
 */
static inline GdkPixbuf *barf_png_via_cairo(const char *path, gint target_size) {
	cairo_surface_t *surf = cairo_image_surface_create_from_png(path);
	if (!surf || cairo_surface_status(surf) != CAIRO_STATUS_SUCCESS) {
		if (surf) cairo_surface_destroy(surf);
		return NULL;
	}
	cairo_surface_flush(surf);
	int w = cairo_image_surface_get_width(surf);
	int h = cairo_image_surface_get_height(surf);
	if (w <= 0 || h <= 0) { cairo_surface_destroy(surf); return NULL; }

	unsigned char *src_data  = cairo_image_surface_get_data(surf);
	int            src_stride = cairo_image_surface_get_stride(surf);

	GdkPixbuf *pb = gdk_pixbuf_new(GDK_COLORSPACE_RGB, TRUE, 8, w, h);
	if (!pb) { cairo_surface_destroy(surf); return NULL; }

	int    dst_stride = gdk_pixbuf_get_rowstride(pb);
	guchar *dst_data  = gdk_pixbuf_get_pixels(pb);

	// Cairo ARGB32 = native-endian 32-bit BGRA on LE, premultiplied.
	// GdkPixbuf   = R,G,B,A bytes, not premultiplied.
	for (int y = 0; y < h; y++) {
		for (int x = 0; x < w; x++) {
			const uint32_t *src = (const uint32_t *)(src_data + y * src_stride) + x;
			guchar         *dst = dst_data + y * dst_stride + x * 4;
			uint8_t a = (*src >> 24) & 0xFF;
			uint8_t r = (*src >> 16) & 0xFF;
			uint8_t g = (*src >>  8) & 0xFF;
			uint8_t b = (*src      ) & 0xFF;
			if (a > 0 && a < 255) {
				r = (uint8_t)MIN(255, (int)(r * 255 + a / 2) / a);
				g = (uint8_t)MIN(255, (int)(g * 255 + a / 2) / a);
				b = (uint8_t)MIN(255, (int)(b * 255 + a / 2) / a);
			}
			dst[0] = r; dst[1] = g; dst[2] = b; dst[3] = a;
		}
	}
	cairo_surface_destroy(surf);

	if (target_size > 0 && (w != target_size || h != target_size)) {
		GdkPixbuf *sc = gdk_pixbuf_scale_simple(pb, target_size, target_size,
		                                         GDK_INTERP_BILINEAR);
		g_object_unref(pb);
		return sc;
	}
	return pb;
}
