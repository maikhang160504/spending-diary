import re

def patch_file():
    with open('lib/screens/chat/chat_screen.dart', 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Update _updateMessagePreviews for searchPreview null override
    content = content.replace('''
      if (report != null || actType.contains('REPORT')) {
        msg.reportPreview = report;
      } else if (search != null || actType.contains('SEARCH')) {
        msg.searchPreview = search;
      } else {
''', '''
      if (report != null || actType.contains('REPORT')) {
        if (report != null) msg.reportPreview = report;
      } else if (search != null || actType.contains('SEARCH')) {
        if (search != null) msg.searchPreview = search;
      } else {
''')

    # 2. Add filtering of save confirmation messages
    content = content.replace('''
        if (displayText == '💾 Đã lưu giao dịch') {
          for (var i = msgs.length - 1; i >= 0; i--) {
            if (msgs[i].txPreview != null || msgs[i].multiRecords != null) {
              msgs[i].isSaved = true;
              break;
            }
          }
        }
        if (displayText == '✅ Đã thực hiện hành động!') {
          for (var i = msgs.length - 1; i >= 0; i--) {
            if (msgs[i].actionPreview != null) {
              msgs[i].isConfirmed = true;
              break;
            }
          }
        }

        msgs.add(
''', '''
        if (displayText == '💾 Đã lưu giao dịch' ||
            displayText == '✅ Đã thực hiện hành động!') {
          if (displayText == '💾 Đã lưu giao dịch') {
            for (var i = msgs.length - 1; i >= 0; i--) {
              if (msgs[i].txPreview != null || msgs[i].multiRecords != null) {
                msgs[i].isSaved = true;
                break;
              }
            }
          }
          if (displayText == '✅ Đã thực hiện hành động!') {
            for (var i = msgs.length - 1; i >= 0; i--) {
              if (msgs[i].actionPreview != null) {
                msgs[i].isConfirmed = true;
                break;
              }
            }
          }
          continue; // Skip adding this message to the UI
        }

        msgs.add(
''')

    # 3. Replace invalidateCache with AppQueries.invalidateWalletData() in _saveTransaction
    content = content.replace('''
      try {
        CachedQuery.instance.invalidateCache(key: 'stories');
        CachedQuery.instance.invalidateCache(key: 'dashboard');
        CachedQuery.instance.invalidateCache(key: 'transactions');
        CachedQuery.instance.invalidateCache(key: 'statsCategory');
        CachedQuery.instance.invalidateCache(key: 'statsMonth');
      } catch (_) {}
''', '''
      try {
        AppQueries.invalidateWalletData();
      } catch (_) {}
''')

    # 4. Replace catch (_) {} with catch (e, st) {} in _saveTransaction
    content = content.replace('''
      await StreakCelebration.instance.afterActivity(context);
    } catch (_) {}
  }

  Future<void> _saveMultiTransaction(_ChatMsg msg, {bool force = false}) async {
''', '''
      await StreakCelebration.instance.afterActivity(context);
    } catch (e, st) {
      debugPrint('Save error: $e');
      debugPrint(st.toString());
      if (mounted) {
        setState(() => msg.isSaved = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _saveMultiTransaction(_ChatMsg msg, {bool force = false}) async {
''')

    # 5. Replace catch (_) {} with catch (e, st) {} in _saveMultiTransaction
    content = content.replace('''
      await StreakCelebration.instance.afterActivity(context);
    } catch (_) {}
  }

  Future<void> _sendActionReply(_ChatMsg msg) async {
''', '''
      await StreakCelebration.instance.afterActivity(context);
    } catch (e, st) {
      debugPrint('Save error: $e');
      debugPrint(st.toString());
      if (mounted) {
        setState(() => msg.isSaved = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _sendActionReply(_ChatMsg msg) async {
''')


    with open('lib/screens/chat/chat_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    patch_file()
