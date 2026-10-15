package com.example.kfc.common.exception;

import com.example.kfc.common.result.ResultCode;

/**
 * 业务异常：由 Service 主动抛出，由全局异常处理器统一转成 Result
 */
public class BusinessException extends RuntimeException {

    private final int code;

    public BusinessException(ResultCode resultCode) {
        super(resultCode.getMessage());
        this.code = resultCode.getCode();
    }

    public BusinessException(String message) {
        super(message);
        this.code = ResultCode.BUSINESS_ERROR.getCode();
    }

    public int getCode() {
        return code;
    }
}
