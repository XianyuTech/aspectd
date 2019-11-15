/// Annotation indicating whether a class should be taken into consideration
/// when searching for aspectd implementations like AOP.
@pragma('vm:entry-point')
class Aspect {
  /// Aspect default constructor
  const factory Aspect() = Aspect._;

  @pragma('vm:entry-point')
  const Aspect._();
}
