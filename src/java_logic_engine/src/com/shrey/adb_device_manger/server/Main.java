package com.shrey.adb_device_manger.server;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.net.ServerSocket;
import java.net.Socket;

/**
 * Logic Engine Entrypoint — Executed via `adb shell app_process` on Port 38947.
 */
public class Main {
    private static final int PORT = 38947;

    public static void main(String[] args) {
        System.out.println("ADB Device Manager Server Started on port " + PORT);

        try (ServerSocket serverSocket = new ServerSocket(PORT)) {
            while (true) {
                Socket clientSocket = serverSocket.accept();
                new Thread(() -> handleClient(clientSocket)).start();
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private static void handleClient(Socket socket) {
        try (
            BufferedReader in = new BufferedReader(new InputStreamReader(socket.getInputStream()));
            PrintWriter out = new PrintWriter(socket.getOutputStream(), true)
        ) {
            String line;
            while ((line = in.readLine()) != null) {
                if (line.contains("GET_DEVICE_WALLPAPER")) {
                    out.println("{\"status\":\"success\",\"wallpaper\":\"...\"}");
                } else if (line.contains("GET_CONTACTS")) {
                    out.println("{\"status\":\"success\",\"count\":0}");
                } else {
                    out.println("{\"status\":\"error\",\"message\":\"Unknown command\"}");
                }
            }
        } catch (Exception e) {
            System.err.println("Client handler error: " + e.getMessage());
        }
    }
}
