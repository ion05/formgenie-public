class Globals {
  static int selectedIndex = 0;
  static String currentFormFirestoreId = '';

  static setSelectedIndex(int index) {
    selectedIndex = index;
  }

  static getSelectedIndex() {
    return selectedIndex;
  }

  static setCurrentFormFirestoreId(String id) {
    currentFormFirestoreId = id;
  }

  static getCurrentFormFirestoreId() {
    return currentFormFirestoreId;
  }
}
