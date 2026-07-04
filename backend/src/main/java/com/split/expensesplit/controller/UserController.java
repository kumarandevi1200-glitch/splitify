package com.split.expensesplit.controller;

import com.split.expensesplit.dto.ProfileUpdateRequest;
import com.split.expensesplit.service.UserService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.security.Principal;

@RestController
@RequestMapping("/api/users")
public class UserController {

    @Autowired
    private UserService userService;

    @PutMapping("/profile")
    public ResponseEntity<Void> updateProfile(@Valid @RequestBody ProfileUpdateRequest request, Principal principal) {
        userService.updateProfile(principal.getName(), request);
        return ResponseEntity.ok().build();
    }
}
