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
//!     - Día de la semana en 3 letras, arriba, en verde.
//!     - Hora H:MM / HH:MM enorme (Roboto Mono Bold 156), blanca. Sin cero
//!       delante en horas de un solo dígito (p. ej. 1:00, no 01:00).
//!     - Día del mes (número grande verde) + mes en 3 letras (acento azul), abajo.
//!     - Sin segundos.
//!
//!   ALWAYS-ON (reposo, pantalla siempre encendida):
//!     - Solo la hora en color vivo (verde/rojo/blanco). ~9% de píxeles
//!       encendidos (Garmin exige <10%), con desplazamiento anti burn-in.
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
    private var mMonFont;    // Medium 70 — mes y día de la semana

    // Colores.
    private const COLOR_BG    = Gfx.COLOR_BLACK;
    private const COLOR_TIME  = 0xFFFFFF; // blanco puro (hora)
    private const COLOR_GREEN = 0x00FF00; // día de la semana y nº del día del mes

    // Posiciones verticales como fracción de la altura de pantalla.
    private const Y_WDAY = 0.200; // día de la semana (arriba, sobre la hora)
    private const Y_TIME = 0.500; // hora (centro)
    private const Y_DATE = 0.815; // fecha (abajo, separada de la hora)

    function initialize() {
        WatchFace.initialize();
    }

    //! Carga las fuentes personalizadas.
    function onLayout(dc) {
        mTimeFont = Ui.loadResource(Rez.Fonts.TimeBig);
        mNumFont  = Ui.loadResource(Rez.Fonts.NumBig);
        mMonFont  = Ui.loadResource(Rez.Fonts.MonBig);
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

        drawWeekday(dc, now.day_of_week);

        drawBigTime(dc, cx, (h * Y_TIME).toNumber(),
                    formatTime(now.hour, now.min), COLOR_TIME);

        drawDayMonth(dc, cx, (h * Y_DATE).toNumber(), now.day, now.month);
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

    //! Día de la semana en 3 letras (verde), arriba, centrado.
    private function drawWeekday(dc, dow) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(COLOR_GREEN, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * Y_WDAY).toNumber(), mMonFont, dayName(dow),
                    Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    //! Dibuja la hora muy grande en tres bloques (HH · : · MM) con el ":"
    //! ceñido. Mide HH y MM por separado para admitir horas de un solo dígito.
    private function drawBigTime(dc, cx, cy, timeStr, color) {
        var colonIdx = timeStr.find(":");
        var hh = timeStr.substring(0, colonIdx);
        var mm = timeStr.substring(colonIdx + 1, timeStr.length());

        var wHH = dc.getTextDimensions(hh, mTimeFont)[0];
        var wMM = dc.getTextDimensions(mm, mTimeFont)[0];
        var wColon = dc.getTextDimensions(":", mTimeFont)[0];
        var colonSlot = (wColon / 2).toNumber();
        var totalW = wHH + colonSlot + wMM;
        var x0 = cx - totalW / 2;

        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x0, cy, mTimeFont, hh,
                    Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x0 + wHH + colonSlot / 2, cy, mTimeFont, ":",
                    Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x0 + wHH + colonSlot, cy, mTimeFont, mm,
                    Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    //! Fecha: número grande del día del mes (blanco) y, a su derecha, el mes
    //! en 3 letras (color de acento). Sin recuadro.
    private function drawDayMonth(dc, cx, cy, day, month) {
        var num = day.format("%d");
        var mon = monthName(month);

        var numW = dc.getTextDimensions(num, mNumFont)[0];
        var monW = dc.getTextDimensions(mon, mMonFont)[0];
        var gap = 14;
        var groupW = numW + gap + monW;
        var x0 = cx - groupW / 2;

        // Número del día del mes en verde.
        dc.setColor(COLOR_GREEN, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x0, cy, mNumFont, num,
                    Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);

        // Mes en azul de acento.
        dc.setColor(mAccentColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x0 + numW + gap, cy, mMonFont, mon,
                    Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
    }

    //! Nombre corto del día (day_of_week: 1=domingo .. 7=sábado -> Day_0..6).
    private function dayName(dow) {
        var id;
        switch (dow) {
            case 1:  id = Rez.Strings.Day_0; break;
            case 2:  id = Rez.Strings.Day_1; break;
            case 3:  id = Rez.Strings.Day_2; break;
            case 4:  id = Rez.Strings.Day_3; break;
            case 5:  id = Rez.Strings.Day_4; break;
            case 6:  id = Rez.Strings.Day_5; break;
            case 7:  id = Rez.Strings.Day_6; break;
            default: id = Rez.Strings.Day_0; break;
        }
        return Ui.loadResource(id);
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

    //! Formatea la hora respetando 12/24 h. Sin cero delante en la hora
    //! (1:00 en vez de 01:00); los minutos sí van a dos dígitos.
    private function formatTime(hour, min) {
        var use24 = mUse24Hour and Sys.getDeviceSettings().is24Hour;
        var h = hour;
        if (!use24) {
            h = hour % 12;
            if (h == 0) {
                h = 12;
            }
        }
        return h.format("%d") + ":" + min.format("%02d");
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
