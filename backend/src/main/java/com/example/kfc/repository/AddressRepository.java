package com.example.kfc.repository;

import com.example.kfc.domain.entity.Address;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * 收货地址模块 —— 持久化层 Repository
 *
 * <p>默认地址排序与查询用 @Query 显式写，避免方法名派生查询
 * 在 isDefault 这种 is 开头的布尔字段上产生歧义。
 */
@Repository
public interface AddressRepository extends JpaRepository<Address, Long> {

    /** 默认地址排在最前 */
    @Query("select a from Address a where a.userId = :userId order by a.isDefault desc, a.id desc")
    List<Address> findByUserId(@Param("userId") Long userId);

    @Query("select a from Address a where a.id = :id and a.userId = :userId")
    Optional<Address> findByIdAndUserId(@Param("id") Long id, @Param("userId") Long userId);

    @Query("select a from Address a where a.userId = :userId and a.isDefault = true")
    Optional<Address> findDefaultByUserId(@Param("userId") Long userId);

    long countByUserId(Long userId);
}
