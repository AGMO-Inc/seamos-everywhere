/**
 * Decrypt modelenc.json from FeatureDesigner.
 *
 * Usage:
 *   javac decrypt_model.java && java DecryptModel <modelenc.json> <output.json>
 *
 * The modelenc.json file is DES-encrypted with key "idtmodel".
 * It is located inside the FeatureDesigner installation:
 *   plugins/com.2partsolutions.idt.server_<version>.jar!/modelenc.json
 */
import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.DESKeySpec;
import java.io.*;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Base64;

public class DecryptModel {
    private static final String DES_KEY = "idtmodel";

    public static void main(String[] args) throws Exception {
        if (args.length < 2) {
            System.err.println("Usage: java DecryptModel <modelenc.json> <output.json>");
            System.exit(1);
        }

        byte[] encrypted = Files.readAllBytes(Paths.get(args[0]));
        byte[] decoded = Base64.getDecoder().decode(encrypted);

        DESKeySpec keySpec = new DESKeySpec(DES_KEY.getBytes("UTF-8"));
        SecretKeyFactory keyFactory = SecretKeyFactory.getInstance("DES");
        SecretKey key = keyFactory.generateSecret(keySpec);

        Cipher cipher = Cipher.getInstance("DES");
        cipher.init(Cipher.DECRYPT_MODE, key);
        byte[] decrypted = cipher.doFinal(decoded);

        Files.write(Paths.get(args[1]), decrypted);
        System.out.println("Decrypted " + args[0] + " -> " + args[1] +
                " (" + decrypted.length + " bytes)");
    }
}
