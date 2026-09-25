// Shell UID를 이용한 실기기 검증 전용. 앱 APK에는 포함하지 않는다.
import android.os.SystemClock;
import android.view.InputEvent;
import android.view.InputDevice;
import android.view.KeyEvent;
import android.view.MotionEvent;
import java.lang.reflect.Method;

public final class DeviceInputProbe {
    static Object manager;
    static Method inject;
    static long down;
    static void event(int action, float... xy) throws Exception {
        int count = xy.length / 2;
        MotionEvent.PointerProperties[] props = new MotionEvent.PointerProperties[count];
        MotionEvent.PointerCoords[] coords = new MotionEvent.PointerCoords[count];
        for (int i=0; i<count; i++) {
            props[i] = new MotionEvent.PointerProperties();
            props[i].id = i; props[i].toolType = MotionEvent.TOOL_TYPE_FINGER;
            coords[i] = new MotionEvent.PointerCoords();
            coords[i].x = xy[i*2]; coords[i].y = xy[i*2+1];
            coords[i].pressure = 1; coords[i].size = 1;
        }
        MotionEvent e = MotionEvent.obtain(down,SystemClock.uptimeMillis(),action,count,props,coords,0,0,1,1,0,0,InputDevice.SOURCE_TOUCHSCREEN,0);
        if (!(Boolean)inject.invoke(manager,e,2)) throw new IllegalStateException("input injection rejected");
        e.recycle();
    }
    static void home() throws Exception {
        for (int action : new int[]{KeyEvent.ACTION_DOWN,KeyEvent.ACTION_UP}) {
            KeyEvent e = new KeyEvent(SystemClock.uptimeMillis(),SystemClock.uptimeMillis(),action,KeyEvent.KEYCODE_HOME,0);
            if (!(Boolean)inject.invoke(manager,e,2)) throw new IllegalStateException("home rejected");
        }
    }
    public static void main(String[] args) throws Exception {
        Class<?> type = Class.forName("android.hardware.input.InputManager");
        manager = type.getMethod("getInstance").invoke(null);
        inject = type.getMethod("injectInputEvent",InputEvent.class,int.class);
        float x = Float.parseFloat(args[1]), y = Float.parseFloat(args[2]);
        down = SystemClock.uptimeMillis();
        event(MotionEvent.ACTION_DOWN,x,y);
        System.out.println("DOWN_READY"); System.out.flush();
        if (args[0].equals("hold")) {
            Thread.sleep(4000);
            event(MotionEvent.ACTION_UP,x,y);
        } else if (args[0].equals("multi")) {
            float tx=Float.parseFloat(args[3]),ty=Float.parseFloat(args[4]);
            float sx=Float.parseFloat(args[5]),sy=Float.parseFloat(args[6]);
            Thread.sleep(120); event(MotionEvent.ACTION_MOVE,tx,ty);
            Thread.sleep(120); event(MotionEvent.ACTION_POINTER_DOWN | (1<<8),tx,ty,sx,sy);
            Thread.sleep(120); event(MotionEvent.ACTION_POINTER_UP | (1<<8),tx,ty,sx,sy);
            Thread.sleep(120); event(MotionEvent.ACTION_UP,tx,ty);
        } else if (args[0].equals("clear_home")) {
            Thread.sleep(50); event(MotionEvent.ACTION_UP,x,y);
            Thread.sleep(Long.parseLong(args[3])); home();
        } else throw new IllegalArgumentException("unknown mode");
        System.out.println("DONE");
    }
}
