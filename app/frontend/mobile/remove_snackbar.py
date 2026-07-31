import re

def patch_file():
    with open('lib/screens/chat/chat_screen.dart', 'r', encoding='utf-8') as f:
        content = f.read()

    # Remove SnackBar in _saveTransaction
    content = content.replace('''
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
''', '''
      await StreakCelebration.instance.afterActivity(context);
    } catch (_) {
      if (mounted) {
        setState(() => msg.isSaved = false);
      }
    }
  }

  Future<void> _saveMultiTransaction(_ChatMsg msg, {bool force = false}) async {
''')

    # Remove SnackBar in _saveMultiTransaction
    content = content.replace('''
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
''', '''
      await StreakCelebration.instance.afterActivity(context);
    } catch (_) {
      if (mounted) {
        setState(() => msg.isSaved = false);
      }
    }
  }

  Future<void> _sendActionReply(_ChatMsg msg) async {
''')


    with open('lib/screens/chat/chat_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    patch_file()
