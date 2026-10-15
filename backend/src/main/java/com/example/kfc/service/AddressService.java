package com.example.kfc.service;

import com.example.kfc.domain.dto.AddressDTO;
import com.example.kfc.domain.vo.AddressVO;

import java.util.List;

/**
 * 收货地址模块 —— 业务逻辑层 Service 接口
 */
public interface AddressService {

    List<AddressVO> listByUser(Long userId);

    AddressVO getById(Long id);

    /** 新增；isDefault = true 时会把该用户其它地址的默认标记清掉 */
    AddressVO create(AddressDTO dto);

    AddressVO update(Long id, AddressDTO dto);

    void delete(Long id, Long userId);
}
