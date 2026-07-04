package com.split.expensesplit.service;

import com.split.expensesplit.dto.ProfileUpdateRequest;
import com.split.expensesplit.entity.User;
import com.split.expensesplit.exception.CustomException;
import com.split.expensesplit.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserService {

    @Autowired
    private UserRepository userRepository;

    @Transactional
    public void updateProfile(String email, ProfileUpdateRequest request) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new CustomException("USER_NOT_FOUND", "User not found", HttpStatus.NOT_FOUND));
        
        user.setName(request.getName());
        userRepository.save(user);
    }
}
