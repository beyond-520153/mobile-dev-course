package com.example.kfc.domain.vo;

import com.example.kfc.domain.entity.Address;
import lombok.Getter;
import lombok.Setter;

/**
 * 收货地址出参
 */
@Getter
@Setter
public class AddressVO {

    private Long id;
    private Long userId;
    private String receiver;
    private String phone;
    private String province;
    private String city;
    private String district;
    private String detail;
    private Boolean isDefault;

    /** 拼接好的整串地址，前端直接展示 */
    private String fullAddress;

    public static AddressVO from(Address a) {
        if (a == null) {
            return null;
        }
        AddressVO vo = new AddressVO();
        vo.setId(a.getId());
        vo.setUserId(a.getUserId());
        vo.setReceiver(a.getReceiver());
        vo.setPhone(a.getPhone());
        vo.setProvince(a.getProvince());
        vo.setCity(a.getCity());
        vo.setDistrict(a.getDistrict());
        vo.setDetail(a.getDetail());
        vo.setIsDefault(a.getIsDefault());
        StringBuilder sb = new StringBuilder();
        if (a.getProvince() != null) {
            sb.append(a.getProvince());
        }
        if (a.getCity() != null) {
            sb.append(a.getCity());
        }
        if (a.getDistrict() != null) {
            sb.append(a.getDistrict());
        }
        if (a.getDetail() != null) {
            sb.append(a.getDetail());
        }
        vo.setFullAddress(sb.toString());
        return vo;
    }
}
