package com.example.kfc.service.impl;

import com.example.kfc.common.exception.BusinessException;
import com.example.kfc.domain.dto.AddressDTO;
import com.example.kfc.domain.entity.Address;
import com.example.kfc.domain.vo.AddressVO;
import com.example.kfc.repository.AddressRepository;
import com.example.kfc.service.AddressService;
import com.example.kfc.service.UserService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

/**
 * 收货地址模块 —— 业务逻辑层实现
 *
 * <p>业务规则：同一用户至多一个默认地址；第一条地址自动成为默认。
 */
@Service
public class AddressServiceImpl implements AddressService {

    private final AddressRepository addressRepository;
    private final UserService userService;

    public AddressServiceImpl(AddressRepository addressRepository, UserService userService) {
        this.addressRepository = addressRepository;
        this.userService = userService;
    }

    @Override
    public List<AddressVO> listByUser(Long userId) {
        return addressRepository.findByUserId(userId)
                .stream()
                .map(AddressVO::from)
                .collect(Collectors.toList());
    }

    @Override
    public AddressVO getById(Long id) {
        return AddressVO.from(addressRepository.findById(id)
                .orElseThrow(() -> new BusinessException("地址不存在：" + id)));
    }

    @Override
    @Transactional
    public AddressVO create(AddressDTO dto) {
        userService.getById(dto.getUserId());

        boolean first = addressRepository.countByUserId(dto.getUserId()) == 0;
        boolean wantDefault = Boolean.TRUE.equals(dto.getIsDefault()) || first;
        if (wantDefault) {
            clearDefault(dto.getUserId());
        }

        Address entity = new Address();
        entity.setUserId(dto.getUserId());
        entity.setReceiver(dto.getReceiver());
        entity.setPhone(dto.getPhone());
        entity.setProvince(dto.getProvince());
        entity.setCity(dto.getCity());
        entity.setDistrict(dto.getDistrict());
        entity.setDetail(dto.getDetail());
        entity.setIsDefault(wantDefault);
        return AddressVO.from(addressRepository.save(entity));
    }

    @Override
    @Transactional
    public AddressVO update(Long id, AddressDTO dto) {
        Address entity = addressRepository.findById(id)
                .orElseThrow(() -> new BusinessException("地址不存在：" + id));

        if (Boolean.TRUE.equals(dto.getIsDefault())) {
            clearDefault(entity.getUserId());
            entity.setIsDefault(true);
        }
        entity.setReceiver(dto.getReceiver());
        entity.setPhone(dto.getPhone());
        entity.setProvince(dto.getProvince());
        entity.setCity(dto.getCity());
        entity.setDistrict(dto.getDistrict());
        entity.setDetail(dto.getDetail());
        return AddressVO.from(addressRepository.save(entity));
    }

    @Override
    @Transactional
    public void delete(Long id, Long userId) {
        Address entity = addressRepository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new BusinessException("地址不存在或不属于该用户"));
        boolean wasDefault = Boolean.TRUE.equals(entity.getIsDefault());
        addressRepository.delete(entity);
        // 必须先真正执行 DELETE 再顶新的默认地址：库上有
        // uk_address_default(user_id) WHERE is_default 的部分唯一索引，
        // Hibernate 默认把 UPDATE 排在 DELETE 前面，中间态会出现两条 is_default=true 而报冲突。
        addressRepository.flush();

        if (wasDefault) {
            List<Address> rest = addressRepository.findByUserId(userId);
            if (!rest.isEmpty()) {
                Address next = rest.get(0);
                next.setIsDefault(true);
                addressRepository.saveAndFlush(next);
            }
        }
    }

    /**
     * 把该用户已有的默认地址取消掉
     *
     * <p>必须立刻 flush：Hibernate 的动作队列是「先 INSERT 后 UPDATE」，
     * 若不清出去，新增默认地址时会先插一条 is_default=true，与旧的默认地址
     * 撞上 uk_address_default 唯一索引。
     */
    private void clearDefault(Long userId) {
        addressRepository.findDefaultByUserId(userId).ifPresent(old -> {
            old.setIsDefault(false);
            addressRepository.saveAndFlush(old);
        });
    }
}
