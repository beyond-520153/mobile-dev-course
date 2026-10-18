package com.example.kfc.service.impl;

import com.example.kfc.common.exception.BusinessException;
import com.example.kfc.domain.dto.OrderCreateDTO;
import com.example.kfc.domain.entity.Order;
import com.example.kfc.domain.entity.OrderItem;
import com.example.kfc.domain.enums.OrderStatus;
import com.example.kfc.domain.vo.CartItemVO;
import com.example.kfc.domain.vo.DiscountLineVO;
import com.example.kfc.domain.vo.OrderItemVO;
import com.example.kfc.domain.vo.OrderQuoteVO;
import com.example.kfc.domain.vo.OrderVO;
import com.example.kfc.repository.OrderItemRepository;
import com.example.kfc.repository.OrderRepository;
import com.example.kfc.service.AddressService;
import com.example.kfc.service.BenefitService;
import com.example.kfc.service.CartItemService;
import com.example.kfc.service.MemberService;
import com.example.kfc.service.OrderItemService;
import com.example.kfc.service.OrderService;
import com.example.kfc.service.ProductService;
import com.example.kfc.service.UserService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ThreadLocalRandom;
import java.util.stream.Collectors;

/**
 * 订单模块 —— 业务逻辑层实现
 *
 * <p>订单与订单明细属于同一个聚合，写入统一在本类完成（同一个事务），
 * OrderItemService 只对外提供查询，避免两个 Service 互相调用来回写。
 *
 * <p>算价只走 {@link BenefitService#quote} 一条路：
 * 结算页试算与真实下单用的是同一个方法，不会出现「页面显示 30、订单扣 38」。
 */
@Service
public class OrderServiceImpl implements OrderService {

    private static final DateTimeFormatter ORDER_NO_FORMAT = DateTimeFormatter.ofPattern("yyyyMMddHHmmss");

    private final OrderRepository orderRepository;
    private final OrderItemRepository orderItemRepository;
    private final CartItemService cartItemService;
    private final ProductService productService;
    private final AddressService addressService;
    private final UserService userService;
    private final OrderItemService orderItemService;
    private final MemberService memberService;
    private final BenefitService benefitService;

    public OrderServiceImpl(OrderRepository orderRepository,
                            OrderItemRepository orderItemRepository,
                            CartItemService cartItemService,
                            ProductService productService,
                            AddressService addressService,
                            UserService userService,
                            OrderItemService orderItemService,
                            MemberService memberService,
                            BenefitService benefitService) {
        this.orderRepository = orderRepository;
        this.orderItemRepository = orderItemRepository;
        this.cartItemService = cartItemService;
        this.productService = productService;
        this.addressService = addressService;
        this.userService = userService;
        this.orderItemService = orderItemService;
        this.memberService = memberService;
        this.benefitService = benefitService;
    }

    @Override
    public List<OrderVO> listByUser(Long userId) {
        return fill(orderRepository.findByUserIdOrderByCreatedAtDesc(userId));
    }

    @Override
    public List<OrderVO> listAll() {
        return fill(orderRepository.findAllByOrderByCreatedAtDesc());
    }

    @Override
    public OrderVO getById(Long id) {
        Order order = getEntity(id);
        OrderVO vo = OrderVO.from(order);
        vo.setItems(orderItemService.listByOrder(id));
        vo.setItemCount(sumQuantity(vo.getItems()));
        return vo;
    }

    @Override
    public OrderQuoteVO quote(Long userId, String pickupType) {
        if (userId == null) {
            throw new BusinessException("用户 id 不能为空");
        }
        userService.getById(userId);
        return benefitService.quote(userId, pickupType, cartItemService.listByUser(userId));
    }

    @Override
    @Transactional
    public OrderVO create(OrderCreateDTO dto) {
        userService.getById(dto.getUserId());

        String pickupType = (dto.getPickupType() == null || dto.getPickupType().isBlank())
                ? "PICKUP" : dto.getPickupType().toUpperCase();
        if ("DELIVERY".equals(pickupType)) {
            if (dto.getAddressId() == null) {
                throw new BusinessException("外送订单必须选择收货地址");
            }
            // 顺带校验地址归属，防止拿别人的地址下单
            addressService.getById(dto.getAddressId());
        }

        List<CartItemVO> cartItems = cartItemService.listByUser(dto.getUserId());
        if (cartItems.isEmpty()) {
            throw new BusinessException("购物车是空的，先去点餐吧");
        }

        // 会员卡权益在这里结算：持大神卡自动享折扣，不需要前端传任何开关
        OrderQuoteVO quote = benefitService.quote(dto.getUserId(), pickupType, cartItems);
        List<DiscountLineVO> discounts = quote.getDiscounts() == null
                ? List.of() : quote.getDiscounts();

        Order order = new Order();
        order.setOrderNo(generateOrderNo());
        order.setUserId(dto.getUserId());
        order.setAddressId(dto.getAddressId());
        order.setPickupType(pickupType);
        order.setTotalAmount(quote.getGoodsAmount());
        order.setDeliveryFee(quote.getDeliveryFee());
        order.setDiscountAmount(quote.getDiscountAmount());
        order.setPayAmount(quote.getPayAmount());
        order.setBenefitCodes(discounts.stream()
                .map(DiscountLineVO::getCode)
                .distinct()
                .collect(Collectors.joining(",")));
        order.setBenefitDetail(discountDetail(discounts));
        order.setStatus(OrderStatus.PENDING_PAYMENT);
        order.setRemark(dto.getRemark());
        Order saved = orderRepository.save(order);

        List<OrderItem> items = new ArrayList<>(cartItems.size());
        for (CartItemVO item : cartItems) {
            // 下单即锁定库存；库存不足会抛业务异常，整个事务回滚
            productService.deductStock(item.getProductId(), item.getQuantity());

            OrderItem row = new OrderItem();
            row.setOrderId(saved.getId());
            row.setProductId(item.getProductId());
            row.setProductName(item.getProductName());
            row.setProductImage(item.getProductImage());
            row.setPrice(item.getPrice());
            row.setQuantity(item.getQuantity());
            row.setSubtotal(item.getSubtotal());
            items.add(row);
        }
        orderItemRepository.saveAll(items);

        // 权益次数在这里扣（不是支付时扣）：下单即锁单，次数和库存同一时点占用
        benefitService.consume(dto.getUserId(), quote);

        // 下单成功后清空购物车（库 + Redis）
        cartItemService.clear(dto.getUserId());

        OrderVO vo = OrderVO.from(saved);
        vo.setItems(items.stream().map(OrderItemVO::from).collect(Collectors.toList()));
        vo.setItemCount(sumQuantity(vo.getItems()));
        return vo;
    }

    @Override
    @Transactional
    public OrderVO pay(Long id) {
        Order order = getEntity(id);
        if (order.getStatus() != OrderStatus.PENDING_PAYMENT) {
            throw new BusinessException("只有待支付的订单可以支付，当前状态：" + order.getStatus().getText());
        }
        order.setStatus(OrderStatus.PAID);
        order.setPayTime(OffsetDateTime.now());
        order.setPickupCode(String.valueOf(ThreadLocalRandom.current().nextInt(1000, 9999)));
        Order saved = orderRepository.save(order);

        // 支付成功给会员累计 V金（消费 1 元 = 1 V金）；该方法内部吞异常，不影响支付
        memberService.accrueVgold(order.getUserId(), order.getPayAmount());

        return getById(saved.getId());
    }

    @Override
    @Transactional
    public OrderVO cancel(Long id) {
        Order order = getEntity(id);
        transfer(order, OrderStatus.CANCELLED);
        restoreStock(order.getId());
        releaseBenefit(order);
        return getById(orderRepository.save(order).getId());
    }

    @Override
    @Transactional
    public OrderVO updateStatus(Long id, OrderStatus status) {
        Order order = getEntity(id);
        transfer(order, status);
        if (status == OrderStatus.CANCELLED) {
            restoreStock(order.getId());
            releaseBenefit(order);
        }
        return getById(orderRepository.save(order).getId());
    }

    /** 订单作废后，把下单时锁掉的库存按明细原数量还回去 */
    private void restoreStock(Long orderId) {
        for (OrderItem item : orderItemRepository.findByOrderIdOrderByIdAsc(orderId)) {
            productService.restoreStock(item.getProductId(), item.getQuantity());
        }
    }

    /**
     * 订单作废后，把本单用掉的权益次数还回去
     *
     * <p>记在「订单创建那天」的流水上：跨零点取消时，减的是昨天的计数，
     * 不会把今天的额度误加回来。
     */
    private void releaseBenefit(Order order) {
        if (order.getBenefitCodes() == null || order.getBenefitCodes().isBlank()) {
            return;
        }
        java.time.LocalDate useDate = order.getCreatedAt() == null ? null
                : order.getCreatedAt().atZoneSameInstant(ZoneId.of("Asia/Shanghai")).toLocalDate();
        benefitService.release(order.getUserId(), order.getBenefitCodes(), useDate);
    }

    /** 优惠文案：一条一行，落库后订单详情直接展示，不用再回算 */
    private String discountDetail(List<DiscountLineVO> discounts) {
        if (discounts.isEmpty()) {
            return null;
        }
        String text = discounts.stream()
                .map(line -> {
                    String title = Boolean.TRUE.equals(line.getOnDeliveryFee())
                            ? "外送费已免" : line.getName();
                    String suffix = line.getItemText() == null || line.getItemText().isBlank()
                            ? "" : "（" + line.getItemText() + "）";
                    return title + " -" + line.getDiscountAmount().toPlainString() + suffix;
                })
                .collect(Collectors.joining("；"));
        return text.length() > 500 ? text.substring(0, 500) : text;
    }

    @Override
    @Transactional
    public void delete(Long id) {
        getEntity(id);
        orderItemRepository.deleteByOrderId(id);
        orderRepository.deleteById(id);
    }

    /** 状态流转校验：不合法直接抛业务异常，状态机在枚举里 */
    private void transfer(Order order, OrderStatus target) {
        if (!order.getStatus().canTransferTo(target)) {
            throw new BusinessException("订单状态不允许从「" + order.getStatus().getText()
                    + "」变更为「" + target.getText() + "」");
        }
        order.setStatus(target);
    }

    /** 批量补明细与件数，避免订单列表逐条查明细 */
    private List<OrderVO> fill(List<Order> orders) {
        if (orders.isEmpty()) {
            return new ArrayList<>();
        }
        Map<Long, List<OrderItemVO>> grouped = orderItemService
                .listByOrders(orders.stream().map(Order::getId).collect(Collectors.toList()))
                .stream()
                .collect(Collectors.groupingBy(OrderItemVO::getOrderId));

        List<OrderVO> result = new ArrayList<>(orders.size());
        for (Order order : orders) {
            OrderVO vo = OrderVO.from(order);
            List<OrderItemVO> items = grouped.getOrDefault(order.getId(), List.of());
            vo.setItems(new ArrayList<>(items));
            vo.setItemCount(sumQuantity(items));
            result.add(vo);
        }
        return result;
    }

    private int sumQuantity(Collection<OrderItemVO> items) {
        return items.stream().mapToInt(OrderItemVO::getQuantity).sum();
    }

    /** 订单号：时间戳 + 4 位随机，撞号就重试 */
    private String generateOrderNo() {
        for (int i = 0; i < 5; i++) {
            String candidate = OffsetDateTime.now().format(ORDER_NO_FORMAT)
                    + ThreadLocalRandom.current().nextInt(1000, 9999);
            if (!orderRepository.existsByOrderNo(candidate)) {
                return candidate;
            }
        }
        throw new BusinessException("订单号生成失败，请重试");
    }

    private Order getEntity(Long id) {
        return orderRepository.findById(id)
                .orElseThrow(() -> new BusinessException("订单不存在：" + id));
    }
}
