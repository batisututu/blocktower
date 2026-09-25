// Isolated QA helper, never packaged with the game. Android app_process entry point.
import java.io.RandomAccessFile;
import java.nio.channels.FileLock;

public final class RecoveryLockProbe {
    public static void main(String[] args) throws Exception {
        try (RandomAccessFile file = new RandomAccessFile(args[0], "rw")) {
            FileLock lock = file.getChannel().tryLock();
            System.out.println((lock == null ? "BUSY " : "LOCKED ") + android.os.Process.myPid());
            System.out.flush();
            if (lock != null) {
                if (args.length > 1 && args[1].equals("hold")) Thread.sleep(60000);
                lock.release();
            }
        }
    }
}
