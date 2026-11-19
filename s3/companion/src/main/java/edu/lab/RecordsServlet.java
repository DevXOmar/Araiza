package edu.lab;

import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.UUID;
import javax.servlet.annotation.MultipartConfig;
import javax.servlet.http.Part;

@WebServlet(urlPatterns = {"/health", "/records", "/resume"})
@MultipartConfig(maxFileSize = 2097152, maxRequestSize = 2162688)
public final class RecordsServlet extends HttpServlet {
    @Override public void init() throws ServletException {
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
        } catch (ClassNotFoundException error) {
            throw new ServletException("JDBC driver is missing", error);
        }
    }

    private Connection connect() throws SQLException {
        return DriverManager.getConnection(System.getenv("DB_URL"),
            System.getenv("DB_USER"), System.getenv("DB_PASSWORD"));
    }

    @Override protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws IOException {
        response.setContentType("text/plain;charset=UTF-8");
        response.setHeader("Cache-Control", "no-store");
        try (Connection db = connect()) {
            if ("/health".equals(request.getServletPath())) {
                try (Statement statement = db.createStatement();
                     ResultSet result = statement.executeQuery("SELECT 1")) {
                    if (!result.next() || result.getInt(1) != 1) {
                        response.sendError(503);
                        return;
                    }
                    response.getWriter().println("database OK");
                }
                return;
            }
            if ("/resume".equals(request.getServletPath())) {
                downloadResume(db, request.getParameter("reference"), response);
                return;
            }
            try (Statement statement = db.createStatement();
                 ResultSet rows = statement.executeQuery(
                     "SELECT reference, position, resume FROM applications ORDER BY reference")) {
                response.getWriter().println("reference\tposition\tresumeDownload");
                while (rows.next()) {
                    response.getWriter().println(rows.getString(1) + "\t" + rows.getString(2) + "\tresume?reference=" + rows.getString(1).replace(" ", "%20"));
                }
            }
        } catch (SQLException error) {
            getServletContext().log("Lab database read failed", error);
            response.sendError(503, "Database unavailable");
        }
    }

    @Override protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws IOException, ServletException {
        request.setCharacterEncoding("UTF-8");
        String reference = request.getParameter("reference");
        String value = request.getParameter("position");
        if (!RecordInput.isValid(reference, value)) {
            response.sendError(400, "Invalid reference or position");
            return;
        }
        Part resume = request.getPart("resume");
        if (resume == null || resume.getSize() == 0) {
            response.sendError(400, "A synthetic resume is required");
            return;
        }
        try (Connection db = connect()) {
            String fileId = UUID.randomUUID().toString();
            Path directory = Paths.get(System.getenv("RESUME_DIRECTORY"));
            Files.createDirectories(directory);
            Path file = directory.resolve(fileId);
            try (InputStream contents = resume.getInputStream()) {
                Files.copy(contents, file);
            }
            try (PreparedStatement insert = db.prepareStatement(
                    "INSERT INTO applications (reference, position, resume) VALUES (?, ?, ?)")) {
                insert.setString(1, reference);
                insert.setString(2, value);
                insert.setString(3, fileId);
                insert.executeUpdate();
            } catch (SQLException error) {
                // On an ambiguous connection failure keep the upload in case the insert committed.
                if ("23000".equals(error.getSQLState())) {
                    Files.deleteIfExists(file);
                }
                throw error;
            }
            response.setStatus(201);
            response.setContentType("text/plain;charset=UTF-8");
            response.getWriter().println("saved " + reference);
        } catch (SQLException error) {
            if ("23505".equals(error.getSQLState()) || error.getErrorCode() == 1062) {
                response.sendError(409, "Reference already exists");
            } else {
                getServletContext().log("Lab database write failed", error);
                response.sendError(503, "Database unavailable");
            }
        }
    }

    private void downloadResume(Connection db, String reference, HttpServletResponse response)
            throws SQLException, IOException {
        try (PreparedStatement query = db.prepareStatement("SELECT resume FROM applications WHERE reference = ?")) {
            query.setString(1, reference);
            try (ResultSet result = query.executeQuery()) {
                if (!result.next()) {
                    response.sendError(404, "Application not found");
                    return;
                }
                Path file = Paths.get(System.getenv("RESUME_DIRECTORY")).resolve(result.getString(1));
                if (!Files.isRegularFile(file)) {
                    response.sendError(404, "Resume missing");
                    return;
                }
                response.setContentType("application/octet-stream");
                response.setHeader("Content-Disposition", "attachment; filename=resume");
                response.setHeader("X-Content-Type-Options", "nosniff");
                Files.copy(file, response.getOutputStream());
            }
        }
    }
}
