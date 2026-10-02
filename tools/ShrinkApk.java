import java.io.BufferedOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;
import java.util.regex.Pattern;
import java.util.zip.CRC32;
import java.util.zip.Deflater;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import java.util.zip.ZipOutputStream;

/**
 * Deflates the textures inside a Godot Android APK.
 *
 * Godot's Android exporter stores every .ctex uncompressed. Our VRAM-compressed
 * (ASTC) art is mostly transparent and deflates about 6x, so repacking with the
 * .ctex entries deflated shrinks the APK by ~200 MB while every file stays
 * byte-identical. Run by tools/shrink_apk.ps1, which also aligns and signs.
 * Design: docs/superpowers/specs/2026-10-02-apk-size-design.md.
 *
 * Usage (JDK 11+ runs this source file directly):
 *   java ShrinkApk.java repack <in.apk> <out.apk>
 *   java ShrinkApk.java verify <in.apk> <out.apk>
 *   java ShrinkApk.java selftest
 */
public class ShrinkApk {
    /** Old v1 signature files. apksigner writes fresh ones after repacking. */
    static final Pattern SIGNATURE = Pattern.compile("META-INF/([^/]+\\.(SF|RSA|DSA|EC)|MANIFEST\\.MF)");

    /** Copy buffer size. */
    static final int BUFFER = 1 << 16;

    public static void main(String[] args) {
        try {
            if (args.length == 3 && args[0].equals("repack")) {
                repack(Path.of(args[1]), Path.of(args[2]));
            } else if (args.length == 3 && args[0].equals("verify")) {
                verify(Path.of(args[1]), Path.of(args[2]));
                System.out.println("verify OK");
            } else if (args.length == 1 && args[0].equals("selftest")) {
                selftest();
                System.out.println("selftest OK");
            } else {
                System.err.println("usage: java ShrinkApk.java repack|verify <in.apk> <out.apk> | selftest");
                System.exit(2);
            }
        } catch (Exception e) {
            System.err.println("ShrinkApk: " + e.getMessage());
            System.exit(1);
        }
    }

    static boolean isTexture(String name) {
        return name.endsWith(".ctex");
    }

    static boolean isSignature(String name) {
        return SIGNATURE.matcher(name).matches();
    }

    /** Writes in -> out with every .ctex deflated, other entries as they were, old signatures dropped. */
    static void repack(Path in, Path out) throws IOException {
        byte[] buf = new byte[BUFFER];
        try (ZipFile zin = new ZipFile(in.toFile());
             ZipOutputStream zout = new ZipOutputStream(new BufferedOutputStream(Files.newOutputStream(out), BUFFER))) {
            zout.setLevel(Deflater.BEST_COMPRESSION);
            for (ZipEntry e : Collections.list(zin.entries())) {
                if (isSignature(e.getName())) continue;
                ZipEntry n = new ZipEntry(e.getName());
                n.setTime(e.getTime());
                n.setMethod(isTexture(e.getName()) ? ZipEntry.DEFLATED : e.getMethod());
                if (n.getMethod() == ZipEntry.STORED) {
                    // ZipOutputStream re-checks this CRC against the bytes it writes.
                    n.setSize(e.getSize());
                    n.setCompressedSize(e.getSize());
                    n.setCrc(e.getCrc());
                }
                zout.putNextEntry(n);
                try (InputStream is = zin.getInputStream(e)) {
                    for (int r; (r = is.read(buf)) > 0; ) zout.write(buf, 0, r);
                }
                zout.closeEntry();
            }
        }
    }

    /** Throws unless out holds exactly in's entries (minus signatures), byte-identical, packed as repack packs them. */
    static void verify(Path in, Path out) throws IOException {
        try (ZipFile zin = new ZipFile(in.toFile()); ZipFile zout = new ZipFile(out.toFile())) {
            Set<String> expected = new HashSet<>();
            for (ZipEntry e : Collections.list(zin.entries())) {
                if (isSignature(e.getName())) continue;
                expected.add(e.getName());
                ZipEntry o = zout.getEntry(e.getName());
                if (o == null) throw new IOException("missing from output: " + e.getName());
                int want = isTexture(e.getName()) ? ZipEntry.DEFLATED : e.getMethod();
                if (o.getMethod() != want) {
                    throw new IOException("wrong packing for " + e.getName() + ": method " + o.getMethod() + ", want " + want);
                }
                long[] got = crcAndSize(zout, o);
                if (got[0] != e.getCrc() || got[1] != e.getSize()) {
                    throw new IOException("content changed: " + e.getName());
                }
            }
            for (ZipEntry o : Collections.list(zout.entries())) {
                if (!expected.contains(o.getName()) && !isSignature(o.getName())) {
                    throw new IOException("unexpected entry in output: " + o.getName());
                }
            }
        }
    }

    /** CRC-32 and length of an entry's bytes, computed by reading them (not trusted from the header). */
    static long[] crcAndSize(ZipFile z, ZipEntry e) throws IOException {
        CRC32 crc = new CRC32();
        long n = 0;
        byte[] buf = new byte[BUFFER];
        try (InputStream is = z.getInputStream(e)) {
            for (int r; (r = is.read(buf)) > 0; ) {
                crc.update(buf, 0, r);
                n += r;
            }
        }
        return new long[] {crc.getValue(), n};
    }

    // ---- self-test -------------------------------------------------------

    interface IORun {
        void run() throws IOException;
    }

    static final String TEXTURE = "assets/.godot/imported/a.png-1.astc.ctex";

    static void selftest() throws IOException {
        Path dir = Files.createTempDirectory("shrinkapk");
        Path in = dir.resolve("in.apk");
        Path out = dir.resolve("out.apk");
        Path bad = dir.resolve("bad.apk");
        // Mostly zeros, like transparent art.
        byte[] texture = new byte[200_000];
        for (int i = 0; i < texture.length; i += 97) texture[i] = (byte) i;

        writeZip(in, entries(texture, ZipEntry.STORED, true));
        repack(in, out);
        try (ZipFile z = new ZipFile(out.toFile())) {
            ZipEntry t = z.getEntry(TEXTURE);
            check(t != null && t.getMethod() == ZipEntry.DEFLATED, "texture is deflated");
            check(t.getCompressedSize() < texture.length / 4, "texture shrank");
            check(z.getEntry("resources.arsc").getMethod() == ZipEntry.STORED, "resources.arsc stays stored");
            check(z.getEntry("classes.dex").getMethod() == ZipEntry.DEFLATED, "dex keeps its packing");
            check(z.getEntry("META-INF/MANIFEST.MF") == null, "old manifest dropped");
            check(z.getEntry("META-INF/CERT.SF") == null, "old .SF dropped");
            check(z.getEntry("META-INF/CERT.RSA") == null, "old .RSA dropped");
            check(z.getEntry("META-INF/services/kept") != null, "other META-INF files kept");
        }
        verify(in, out);

        byte[] tampered = texture.clone();
        tampered[5] = 42;
        writeZip(bad, entries(tampered, ZipEntry.DEFLATED, false));
        checkFails(() -> verify(in, bad), "content changed");

        writeZip(bad, entries(texture, ZipEntry.STORED, false));
        checkFails(() -> verify(in, bad), "wrong packing");

        Object[][] missing = entries(texture, ZipEntry.DEFLATED, false);
        writeZip(bad, java.util.Arrays.copyOf(missing, missing.length - 1));
        checkFails(() -> verify(in, bad), "missing from output");

        Object[][] extra = java.util.Arrays.copyOf(missing, missing.length + 1);
        extra[missing.length] = new Object[] {"assets/sneaky.txt", "x".getBytes(), ZipEntry.DEFLATED};
        writeZip(bad, extra);
        checkFails(() -> verify(in, bad), "unexpected entry");
    }

    /** A tiny APK-shaped zip. withSignature adds old v1 signature files. */
    static Object[][] entries(byte[] texture, int textureMethod, boolean withSignature) {
        Object[][] base = {
            {TEXTURE, texture, textureMethod},
            {"resources.arsc", "arsc".getBytes(), ZipEntry.STORED},
            {"classes.dex", "dex dex dex dex".getBytes(), ZipEntry.DEFLATED},
            {"META-INF/services/kept", "kept".getBytes(), ZipEntry.DEFLATED},
        };
        if (!withSignature) return base;
        Object[][] all = java.util.Arrays.copyOf(base, base.length + 3);
        all[base.length] = new Object[] {"META-INF/MANIFEST.MF", "m".getBytes(), ZipEntry.DEFLATED};
        all[base.length + 1] = new Object[] {"META-INF/CERT.SF", "s".getBytes(), ZipEntry.DEFLATED};
        all[base.length + 2] = new Object[] {"META-INF/CERT.RSA", "r".getBytes(), ZipEntry.STORED};
        return all;
    }

    static void writeZip(Path path, Object[][] entries) throws IOException {
        try (ZipOutputStream z = new ZipOutputStream(Files.newOutputStream(path))) {
            for (Object[] e : entries) {
                byte[] data = (byte[]) e[1];
                ZipEntry n = new ZipEntry((String) e[0]);
                n.setMethod((Integer) e[2]);
                if (n.getMethod() == ZipEntry.STORED) {
                    CRC32 crc = new CRC32();
                    crc.update(data);
                    n.setSize(data.length);
                    n.setCompressedSize(data.length);
                    n.setCrc(crc.getValue());
                }
                z.putNextEntry(n);
                z.write(data);
                z.closeEntry();
            }
        }
    }

    static void check(boolean ok, String what) {
        if (!ok) throw new IllegalStateException("selftest failed: " + what);
    }

    static void checkFails(IORun r, String reason) {
        try {
            r.run();
        } catch (IOException e) {
            if (e.getMessage() != null && e.getMessage().contains(reason)) return;
            throw new IllegalStateException("selftest: expected '" + reason + "', got: " + e.getMessage());
        }
        throw new IllegalStateException("selftest: verify accepted a bad APK (" + reason + ")");
    }
}
