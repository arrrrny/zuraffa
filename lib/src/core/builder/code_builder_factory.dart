import 'package:code_builder/code_builder.dart';

import 'factories/repository_factory.dart';
import 'factories/route_factory.dart';
import 'factories/usecase_factory.dart';
import 'factories/vpc_factory.dart';
import 'shared/spec_library.dart';

class CodeBuilderFactory {
  final SpecLibrary specLibrary;

  const CodeBuilderFactory({this.specLibrary = const SpecLibrary()});

  Library repository(RepositorySpecConfig config) {
    return RepositoryFactory(specLibrary: specLibrary).build(config);
  }

  Library usecase(UseCaseSpecConfig config) {
    return UseCaseFactory(specLibrary: specLibrary).build(config);
  }

  Library vpcController(VpcSpecConfig config) {
    return VpcFactory(specLibrary: specLibrary).buildController(config);
  }

  Library vpcPresenter(VpcSpecConfig config) {
    return VpcFactory(specLibrary: specLibrary).buildPresenter(config);
  }

  Library vpcState(VpcSpecConfig config) {
    return VpcFactory(specLibrary: specLibrary).buildState(config);
  }

  Library route(RouteSpecConfig config) {
    return RouteFactory(specLibrary: specLibrary).build(config);
  }
}
