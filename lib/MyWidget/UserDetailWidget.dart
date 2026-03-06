import 'package:flutter/material.dart';
import 'package:qa_imageprocess/model/user.dart';

class UserDetailWidget extends StatelessWidget {
  final User user;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> collectorTypes;
  final List<Map<String, dynamic>> questionDirections;
  final String? selectedCategoryId;
  final String? selectedCollectorTypeId;
  final String? selectedQuestionDirectionId;
  final int? selectedDifficulty;
  final TextEditingController countController;
  final Function(String?, String?) onCategorySelected;
  final Function(String?, String?) onCollectorTypeSelected;
  final Function(String?, String?) onQuestionDirectionSelected;
  final Function(int?) onDifficultySelected;
  final VoidCallback onAssignTask;

  const UserDetailWidget({
    super.key,
    required this.user,
    required this.categories,
    required this.collectorTypes,
    required this.questionDirections,
    required this.selectedCategoryId,
    required this.selectedCollectorTypeId,
    required this.selectedQuestionDirectionId,
    required this.selectedDifficulty,
    required this.countController,
    required this.onCategorySelected,
    required this.onCollectorTypeSelected,
    required this.onQuestionDirectionSelected,
    required this.onDifficultySelected,
    required this.onAssignTask,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户基本信息
            _buildUserInfoSection(context),

            const SizedBox(height: 30),

            // 任务参数部分
            _buildTaskParametersSection(context),

            const SizedBox(height: 30),

            // 任务难度和数量部分
            _buildTaskOptionsSection(context),

            const SizedBox(height: 40),

            // 分配任务按钮
            Center(
              child: ElevatedButton(
                onPressed: onAssignTask,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                child: const Text(
                  '分配任务',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoSection(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, size: 30),
                const SizedBox(width: 10),
                Text(
                  user.name,
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _buildInfoItem('ID', user.userID.toString()),
            _buildInfoItem('邮箱', user.email),
            _buildInfoItem('角色', User.getUserRole(user.role ?? 0)),
            _buildInfoItem('状态', User.getUserState(user.state ?? 0)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildTaskParametersSection(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.task, size: 24, color: Colors.blue),
                const SizedBox(width: 8),
                Text('任务参数配置', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            _buildDropdownFormField(
              label: '采集类目 *',
              value: selectedCategoryId,
              items: categories.map((e) => e['id'] as String).toList(),
              displayItems: categories.fold({}, (map, item) {
                map[item['id']] = item['name'];
                return map;
              }),
              onChanged: (value) {
                final name = categories.firstWhere(
                  (e) => e['id'] == value,
                  orElse: () => {'name': ''},
                )['name'];
                onCategorySelected(value, name);
              },
            ),
            const SizedBox(height: 16),
            _buildDropdownFormField(
              label: '采集类型 *',
              value: selectedCollectorTypeId,
              items: collectorTypes.map((e) => e['id'] as String).toList(),
              displayItems: collectorTypes.fold({}, (map, item) {
                map[item['id']] = item['name'];
                return map;
              }),
              enabled: categories.isNotEmpty && selectedCategoryId != null,
              onChanged: (value) {
                final name = collectorTypes.firstWhere(
                  (e) => e['id'] == value,
                  orElse: () => {'name': ''},
                )['name'];
                onCollectorTypeSelected(value, name);
              },
            ),
            const SizedBox(height: 16),
            _buildDropdownFormField(
              label: '问题方向 *',
              value: selectedQuestionDirectionId,
              items: questionDirections.map((e) => e['id'] as String).toList(),
              displayItems: questionDirections.fold({}, (map, item) {
                map[item['id']] = item['name'];
                return map;
              }),
              enabled:
                  collectorTypes.isNotEmpty && selectedCollectorTypeId != null,
              onChanged: (value) {
                final name = questionDirections.firstWhere(
                  (e) => e['id'] == value,
                  orElse: () => {'name': ''},
                )['name'];
                onQuestionDirectionSelected(value, name);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskOptionsSection(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, size: 24, color: Colors.green),
                const SizedBox(width: 8),
                Text('任务选项', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            _buildDifficultyDropdown(),
            const SizedBox(height: 20),
            _buildCountInputField(),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyDropdown() {
    final difficultyOptions = {0: '简单', 1: '中等', 2: '困难'};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '任务难度 *',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int?>(
          value: selectedDifficulty,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            hintText: '选择任务难度',
          ),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('请选择难度', style: TextStyle(color: Colors.grey)),
            ),
            ...difficultyOptions.entries.map((entry) {
              return DropdownMenuItem<int?>(
                value: entry.key,
                child: Text(entry.value),
              );
            }).toList(),
          ],
          onChanged: onDifficultySelected,
          validator: (value) {
            if (value == null) return '请选择任务难度';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCountInputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '任务数量 *',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: countController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: '请输入任务数量',
            prefixIcon: Icon(Icons.numbers),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty || int.tryParse(value) == null) {
              return '请输入有效的数字';
            }
            return null;
          },
        ),
        const SizedBox(height: 4),
        const Text(
          '注：任务数量应为大于0的整数',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildDropdownFormField({
    required String? value,
    required List<String> items,
    required Map<String, String> displayItems,
    required String label,
    bool enabled = true,
    required ValueChanged<String?> onChanged,
  }) {
    final dropdownItems = [
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('请选择', style: TextStyle(color: Colors.grey)),
      ),
      ...items.map((id) {
        return DropdownMenuItem<String?>(
          value: id,
          child: Text(
            displayItems[id] ?? '未知',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            enabled: enabled,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          items: dropdownItems,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}
