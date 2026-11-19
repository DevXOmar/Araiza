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


@WebServlet(urlPatterns = {"/health", "/records"})

public final class RecordsServlet extends HttpServlet {
    @Override public void init() throws ServletException {
        try {
            Class.forName("org.postgresql.Driver");
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

            try (Statement statement = db.createStatement();
                 ResultSet rows = statement.executeQuery(
                     "SELECT reference, department FROM appointments ORDER BY reference")) {
                response.getWriter().println("reference\tdepartment");
                while (rows.next()) {
                    response.getWriter().println(rows.getString(1) + "\t" + rows.getString(2));
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
        String value = request.getParameter("department");
        if (!RecordInput.isValid(reference, value)) {
            response.sendError(400, "Invalid reference or department");
            return;
        }

        try (Connection db = connect()) {

            try (PreparedStatement insert = db.prepareStatement(
                    "INSERT INTO appointments (reference, department) VALUES (?, ?)")) {
                insert.setString(1, reference);
                insert.setString(2, value);

                insert.executeUpdate();
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

}
