class LamportClock {
  LamportClock(this._value);

  int _value;

  int get current => _value;

  int next() {
    _value += 1;
    return _value;
  }

  void observe(int remoteValue) {
    if (remoteValue > _value) {
      _value = remoteValue;
    }
  }
}
