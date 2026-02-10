// ignore_for_file: no_logic_in_create_state

import 'package:flutter/material.dart';
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/repositories/product_repository.dart';
import 'product_controller.dart';
import 'product_presenter.dart';

class ProductView extends CleanView {
  const ProductView({
    super.key,
    super.routeObserver,
    required this.productRepository,
    this.id,
  });

  final ProductRepository productRepository;

  final String? id;

  @override
  State<ProductView> createState() {
    return _ProductViewState(
      ProductController(ProductPresenter(productRepository: productRepository)),
    );
  }
}

class _ProductViewState extends CleanViewState<ProductView, ProductController> {
  _ProductViewState(super.controller);

  @override
  onInitState() {
    super.onInitState();
    controller.getProductList();
  }

  @override
  Widget get view {
    return Scaffold(
      key: globalKey,
      appBar: AppBar(title: const Text('Product')),
      body: ControlledWidgetBuilder<ProductController>(
        builder: (context, controller) {
          return Container();
        },
      ),
    );
  }
}
