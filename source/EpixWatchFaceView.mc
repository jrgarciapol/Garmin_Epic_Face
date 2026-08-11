using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Calendar;
using Toybox.Application as App;

//! Esfera digital para el Epix Pro 51 mm (454 x 454, AMOLED), pensada para
//! MÁXIMA LEGIBILIDAD, con fuentes Roboto Mono (open source).
//!
//! Dos presentaciones:
//!
//!   INTERACTIVA (mirando el reloj):
//!     - Tira semanal: 7 puntos (L M X J V S D) con el día de hoy resaltado
//!       en color de acento -> el día de la semana se lee "de un vistazo".
//!     - Hora HH:MM enorme (Roboto Mono Bold 156), blanca.
//!     - Día del mes: número grande dentro de un recuadro ("ventana de fecha").
//!     - Sin segundos.
//!
//!   ALWAYS-ON (reposo, pantalla siempre encendida):
//!     - Solo la hora HH:MM (misma fuente grande) en color vivo (verde/rojo/
//!       blanco). ~9,2% de píxeles encendidos (Garmin exige <10%).
//!     - Desplazamiento de píxeles cada minuto para evitar quemado del AMOLED.
class EpixWatchFaceView extends Ui.WatchFace {

    // ¿Pantalla en alto consumo (el usuario la está mirando)?
    private var mIsAwake = true;

    // Ajustes configurables por el usuario.
    private var mUse24Hour = true;
    private var mAccentColor = 0x1E9BFF; // azul (acento interactivo)
    private var mAodColor = 0x00FF00;    // verde (hora en AOD)

    // Fuentes personalizadas (Roboto Mono).
    private var mTimeFont;   // Bold 156 — hora (interactivo + AOD)
    private var mNumFont;    // Bold 78  — número del día del mes
    private var mMonFont;    // Medium 54 — mes (3 letras)
    private var mInitFont;   // Medium 32 — iniciales de la tira semanal

    // Colores.
    private const COLOR_BG   = Gfx.COLOR_BLACK;
    private const COLOR_TIME = 0xFFFFFF; // blanco puro
    private const COLOR_DIM  = 0x666666; // gris de los días no activos

    // Posiciones verticales como fracción de la altura de pantalla.
    private const Y_STRIP = 0.235; // tira semanal (arriba)
    private const Y_TIME  = 0.500; // hora (centro)
    private const Y_DATE  = 0.815; // fecha (abajo, separada de la hora)

    function initialize() {
        WatchFace.initialize();
    }

    //! Carga las fuentes personalizadas.
    function onLayout(dc) {
        mTimeFont = Ui.loadResource(Rez.Fonts.TimeBig);
        mNumFont  = Ui.loadResource(Rez.Fonts.NumBig);
        mMonFont  = Ui.loadResource(Rez.Fonts.MonBig);
        mInitFont = Ui.loadResource(Rez.Fonts.DateMed);
        loadSettings();
    }

    function loadSettings() {
        var use24 = App.Properties.getValue("Use24Hour");
        if (use24 != null) {
            mUse24Hour = use24;
        }
        var accent = App.Properties.getValue("AccentColor");
        if (accent != null) {
            mAccentColor = accent;
        }
        var aod = App.Properties.getValue("AodColor");
        if (aod != null) {
            mAodColor = aod;
        }
    }

    function onShow() {
        loadSettings();
    }

    //! Redibujado principal.
    function onUpdate(dc) {
        loadSettings();

        dc.setColor(COLOR_BG, COLOR_BG);
        dc.clear();

        var now = Calendar.info(Time.now(), Time.FORMAT_SHORT);

        if (mIsAwake) {
            drawInteractive(dc, now);
        } else {
            drawAlwaysOn(dc, now);
        }
    }

    //! ---- Presentación INTERACTIVA ----
    private function drawInteractive(dc, now) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        drawWeekStrip(dc, cx, (h * Y_STRIP).toNumber(), now.day_of_week);

        drawBigTime(dc, cx, (h * Y_TIME).toNumber(),
                    formatTime(now.hour, now.min), COLOR_TIME);

        drawDayWindow(dc, cx, (h * Y_DATE).toNumber(), now.day, now.month);
    }

    //! ---- Presentación ALWAYS-ON (solo la hora) ----
    private function drawAlwaysOn(dc, now) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        // Desplazamiento de píxeles: 9 posiciones que rotan cada minuto para
        // no fijar siempre los mismos píxeles (evita el quemado del AMOLED).
        var shift = 8;
        var ox = ((now.min % 3) - 1) * shift;
        var oy = (((now.min / 3) % 3) - 1) * shift;

        drawBigTime(dc, w / 2 + ox, h / 2 + oy,
                    formatTime(now.hour, now.min), mAodColor);
    }

    //! Dibuja HH:MM muy grande en tres bloques (HH · : · MM) con el ":" ceñido,
    //! para que los dígitos sean lo más grandes posible sin salirse de la
    //! pantalla redonda. Centrado en (cx, cy).
    private function drawBigTime(dc, cx, cy, timeStr, color) {
        var colonIdx = timeStr.find(":");
        var hh = timeStr.substring(0, colonIdx);
        var mm = timeStr.substring(colonIdx + 1, timeStr.length());

        var wBlock = dc.getTextDimensions(hh, mTimeFont)[0];
        var wColon = dc.getTextDimensions(":", mTimeFont)[0];
        var colonSlot = (wColon / 2).toNumber();
        var totalW = wBlock * 2 + colonSlot;
        var x0 = cx - totalW / 2;

        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x0, cy, mTimeFont, hh,
                    Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x0 + wBlock + colonSlot / 2, cy, mTimeFont, ":",
                    Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x0 + wBlock + colonSlot, cy, mTimeFont, mm,
                    Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    //! Tira semanal: 7 puntos con iniciales (L M X J V S D, lunes primero).
    //! El día de hoy se resalta con un círculo de acento y letra blanca; el
    //! resto van en gris. Así el día de la semana se lee por posición/color.
    private function drawWeekStrip(dc, cx, cy, dow) {
        var initials = "LMXJVSD";
        // day_of_week de FORMAT_SHORT: 1=domingo .. 7=sábado.
        // Convertimos a índice con lunes primero (0=lunes .. 6=domingo).
        var todayIdx = (dow + 5) % 7;

        var n = 7;
        var step = 40;              // separación entre centros
        var r = 17;                 // radio del círculo resaltado
        var startX = cx - (step * (n - 1)) / 2;

        for (var i = 0; i < n; i += 1) {
            var x = startX + i * step;
            var ch = initials.substring(i, i + 1);

            if (i == todayIdx) {
                dc.setColor(mAccentColor, Gfx.COLOR_TRANSPARENT);
                dc.fillCircle(x, cy, r);
                dc.setColor(COLOR_TIME, mAccentColor);
                dc.drawText(x, cy, mInitFont, ch,
                            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
            } else {
                dc.setColor(COLOR_DIM, Gfx.COLOR_TRANSPARENT);
                dc.drawText(x, cy, mInitFont, ch,
                            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
            }
        }
    }

    //! Fecha: número grande del día del mes (blanco) y, a su derecha, el mes
    //! en 3 letras (color de acento). Sin recuadro. Todo grande = legible.
    private function drawDayWindow(dc, cx, cy, day, month) {
        var num = day.format("%d");
        var mon = monthName(month);

        var numW = dc.getTextDimensions(num, mNumFont)[0];
        var monW = dc.getTextDimensions(mon, mMonFont)[0];
        var gap = 14;
        var groupW = numW + gap + monW;
        var x0 = cx - groupW / 2;

        // Número (blanco) alineado a la izquierda del grupo, centrado vertical.
        dc.setColor(COLOR_TIME, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x0, cy, mNumFont, num,
                    Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);

        // Mes (acento) a la derecha del número.
        dc.setColor(mAccentColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x0 + numW + gap, cy, mMonFont, mon,
                    Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    //! Nombre corto del mes (1 = enero), desde recursos (ES/EN).
    private function monthName(month) {
        var id;
        switch (month) {
            case 1:  id = Rez.Strings.Mon_1;  break;
            case 2:  id = Rez.Strings.Mon_2;  break;
            case 3:  id = Rez.Strings.Mon_3;  break;
            case 4:  id = Rez.Strings.Mon_4;  break;
            case 5:  id = Rez.Strings.Mon_5;  break;
            case 6:  id = Rez.Strings.Mon_6;  break;
            case 7:  id = Rez.Strings.Mon_7;  break;
            case 8:  id = Rez.Strings.Mon_8;  break;
            case 9:  id = Rez.Strings.Mon_9;  break;
            case 10: id = Rez.Strings.Mon_10; break;
            case 11: id = Rez.Strings.Mon_11; break;
            case 12: id = Rez.Strings.Mon_12; break;
            default: id = Rez.Strings.Mon_1;  break;
        }
        return Ui.loadResource(id);
    }

    //! Formatea la hora respetando 12/24 h del usuario y del sistema.
    private function formatTime(hour, min) {
        var use24 = mUse24Hour and Sys.getDeviceSettings().is24Hour;
        var h = hour;
        if (!use24) {
            h = hour % 12;
            if (h == 0) {
                h = 12;
            }
        }
        return h.format("%02d") + ":" + min.format("%02d");
    }

    //! Alto consumo: repintamos al instante para respuesta inmediata al gesto.
    function onExitSleep() {
        mIsAwake = true;
        Ui.requestUpdate();
    }

    //! Bajo consumo: pasamos a la presentación Always-On.
    function onEnterSleep() {
        mIsAwake = false;
        Ui.requestUpdate();
    }
}
