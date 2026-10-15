package com.example.kfc.common.exception;

import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * 全局异常处理
 * TODO 补充 @ExceptionHandler，把 BusinessException / 参数校验异常 / 兜底异常统一转成 Result
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    // TODO @ExceptionHandler(BusinessException.class)
    // TODO @ExceptionHandler(MethodArgumentNotValidException.class)
    // TODO @ExceptionHandler(Exception.class)
}
