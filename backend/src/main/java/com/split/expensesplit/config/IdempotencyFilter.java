package com.split.expensesplit.config;

import com.split.expensesplit.entity.IdempotencyRecord;
import com.split.expensesplit.repository.IdempotencyRecordRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.util.ContentCachingResponseWrapper;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

@Component
public class IdempotencyFilter extends OncePerRequestFilter {

    @Autowired
    private IdempotencyRecordRepository idempotencyRecordRepository;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        String path = request.getRequestURI();
        String method = request.getMethod();

        // Idempotency applies to POST /api/groups/{id}/expenses and POST /api/groups/{id}/settlements
        boolean isApplicablePath = path.contains("/expenses") || path.contains("/settlements");
        boolean isPost = "POST".equalsIgnoreCase(method);

        if (!isPost || !isApplicablePath) {
            filterChain.doFilter(request, response);
            return;
        }

        String idempotencyKey = request.getHeader("Idempotency-Key");
        if (idempotencyKey == null || idempotencyKey.trim().isEmpty()) {
            filterChain.doFilter(request, response);
            return;
        }

        // Check if key already exists
        var existingRecordOpt = idempotencyRecordRepository.findById(idempotencyKey);
        if (existingRecordOpt.isPresent()) {
            IdempotencyRecord record = existingRecordOpt.get();
            response.setContentType("application/json");
            response.setCharacterEncoding("UTF-8");
            response.setStatus(record.getStatusCode());
            response.getWriter().write(record.getResponseBody());
            response.getWriter().flush();
            return;
        }

        // Key doesn't exist, proceed and capture the response
        ContentCachingResponseWrapper wrappedResponse = new ContentCachingResponseWrapper(response);

        try {
            filterChain.doFilter(request, wrappedResponse);
            
            int status = wrappedResponse.getStatus();
            // Cache successful responses (2xx)
            if (status >= 200 && status < 300) {
                byte[] bodyBytes = wrappedResponse.getContentAsByteArray();
                String responseBody = new String(bodyBytes, StandardCharsets.UTF_8);
                
                IdempotencyRecord record = new IdempotencyRecord(idempotencyKey, responseBody, status);
                idempotencyRecordRepository.save(record);
            }
        } finally {
            // Write cache back to client
            wrappedResponse.copyBodyToResponse();
        }
    }
}
