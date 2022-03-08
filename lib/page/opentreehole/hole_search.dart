/*
 *     Copyright (C) 2021  DanXi-Dev
 *
 *     This program is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     This program is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:io';

import 'package:dan_xi/generated/l10n.dart';
import 'package:dan_xi/model/opentreehole/hole.dart';
import 'package:dan_xi/model/opentreehole/tag.dart';
import 'package:dan_xi/provider/settings_provider.dart';
import 'package:dan_xi/repository/opentreehole/opentreehole_repository.dart';
import 'package:dan_xi/util/lazy_future.dart';
import 'package:dan_xi/util/master_detail_view.dart';
import 'package:dan_xi/util/noticing.dart';
import 'package:dan_xi/widget/libraries/future_widget.dart';
import 'package:dan_xi/widget/libraries/platform_app_bar_ex.dart';
import 'package:dan_xi/widget/opentreehole/treehole_widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_progress_dialog/flutter_progress_dialog.dart';
import 'package:provider/provider.dart';

/// A list page showing the reports for administrators.
class OTSearchPage extends StatelessWidget {
  final Map<String, dynamic>? arguments;

  OTSearchPage({Key? key, this.arguments}) : super(key: key);

  final List<SearchSuggestionProvider> suggestionProviders = [
    searchByText,
    searchByPid,
    searchByFloorId,
    searchByTag
  ];

  /// The text user inputs.
  final TextEditingController _searchFieldController = TextEditingController();

  Widget _buildSearchHistory(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(S.of(context).history),
                PlatformTextButton(
                    alignment: Alignment.centerLeft,
                    child: Text(S.of(context).clear),
                    onPressed: () =>
                        SettingsProvider.getInstance().searchHistory = null),
              ],
            ),
          ),
          Flexible(
            fit: FlexFit.loose,
            child: Selector<SettingsProvider, List<String>>(
                selector: (_, model) => model.searchHistory,
                builder: (_, value, __) => ListView(
                      primary: false,
                      shrinkWrap: true,
                      //reverse: true,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: value
                          .map((e) => PlatformTextButton(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 0, horizontal: 16),
                                alignment: Alignment.centerLeft,
                                child: Text(e),
                                onPressed: () =>
                                    _searchFieldController.text = e,
                              ))
                          .toList(growable: false),
                    )),
          ),
        ],
      );

  /// Build a list of search suggestion or search history if no input.
  Widget buildSearchSuggestion(BuildContext context) =>
      Consumer<TextEditingValue>(
          builder: (context, value, child) => value.text.isEmpty
              ? _buildSearchHistory(context)
              : Expanded(
                  child: Material(
                    child: ListView(
                      primary: false,
                      shrinkWrap: true,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      children: suggestionProviders
                          .map((e) => e.call(context, value.text))
                          .toList(),
                    ),
                  ),
                ));

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      iosContentPadding: false,
      iosContentBottomPadding: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PlatformAppBarX(
        title: Text(S.of(context).search),
        trailingActions: const [],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Hero(
              transitionOnUserGestures: true,
              tag: 'OTSearchWidget',
              child: Padding(
                padding: Theme.of(context).cardTheme.margin ??
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: PlatformTextField(
                  autofocus: true,
                  controller: _searchFieldController,
                  hintText: S.of(context).search_hint,
                ),
              ),
            ),
            ValueListenableProvider.value(
                value: _searchFieldController,
                child: buildSearchSuggestion(context)),
          ],
        ),
      ),
    );
  }
}

/// Some search suggestion providers.
final RegExp pidPattern = RegExp(r'#{1}([0-9]+)');
final RegExp floorPattern = RegExp(r'#{2}([0-9]+)');

Widget searchByText(BuildContext context, String searchKeyword) {
  return ListTile(
    title: Text(S.of(context).search_by_text_tip(searchKeyword)),
    leading: const Icon(Icons.text_fields),
    onTap: () {
      submit(context, searchKeyword);
      smartNavigatorPush(context, "/bbs/postDetail",
          arguments: {"searchKeyword": searchKeyword});
    },
  );
}

Widget searchByPid(BuildContext context, String searchKeyword) {
  final pidMatch = pidPattern.firstMatch(searchKeyword);
  if (pidMatch != null) {
    return ListTile(
      leading: const Icon(Icons.message),
      title: Text(S.of(context).search_by_pid_tip(pidMatch.group(0)!)),
      onTap: () {
        submit(context, searchKeyword);
        _goToPIDResultPage(context, int.parse(pidMatch.group(1)!));
      },
    );
  } else {
    return Container();
  }
}

Widget searchByFloorId(BuildContext context, String searchKeyword) {
  final floorMatch = floorPattern.firstMatch(searchKeyword);
  if (floorMatch != null) {
    return ListTile(
      leading: const Icon(Icons.message),
      title: Text(S.of(context).search_by_floor_tip(floorMatch.group(0)!)),
      onTap: () {
        submit(context, searchKeyword);
        _goToFloorIdResultPage(context, int.parse(floorMatch.group(1)!));
      },
    );
  } else {
    return Container();
  }
}

Widget searchByTag(BuildContext context, String searchKeyword) {
  return FutureWidget<List<OTTag>?>(
      future: LazyFuture.pack(OpenTreeHoleRepository.getInstance().loadTags()),
      successBuilder: (context, snapshot) {
        Iterable<OTTag> suggestionList = snapshot.data!.where((element) =>
            element.name != null &&
            element.name!.toLowerCase().contains(searchKeyword.toLowerCase()));
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: suggestionList
              .map((e) => ListTile(
                    leading: Icon(PlatformIcons(context).tag),
                    title: Text(S.of(context).search_by_tag_tip(e.name!)),
                    onTap: () {
                      submit(context, searchKeyword);
                      smartNavigatorPush(context, '/bbs/discussions',
                          arguments: {"tagFilter": e.name},
                          forcePushOnMainNavigator: true);
                    },
                  ))
              .toList(),
        );
      },
      errorBuilder: Container(),
      loadingBuilder: Container());
}

/// Go to the post page with specific pid.
Future<void> _goToPIDResultPage(BuildContext context, int pid) async {
  ProgressFuture progressDialog =
      showProgressDialog(loadingText: S.of(context).loading, context: context);
  try {
    final OTHole? post =
        await OpenTreeHoleRepository.getInstance().loadSpecificHole(pid);
    smartNavigatorPush(context, "/bbs/postDetail", arguments: {
      "post": post!,
    });
  } catch (error, st) {
    if (error is DioError &&
        error.response?.statusCode == HttpStatus.notFound) {
      Noticing.showNotice(context, S.of(context).post_does_not_exist,
          title: S.of(context).fatal_error, useSnackBar: false);
    } else {
      Noticing.showModalError(context, error, trace: st);
    }
  } finally {
    progressDialog.dismiss(showAnim: false);
  }
}

Future<void> _goToFloorIdResultPage(BuildContext context, int floorId) async {
  ProgressFuture progressDialog =
      showProgressDialog(loadingText: S.of(context).loading, context: context);
  try {
    final floor = (await OpenTreeHoleRepository.getInstance()
        .loadSpecificFloor(floorId))!;
    OTFloorMentionWidget.showFloorDetail(context, floor);
  } catch (error, st) {
    if (error is DioError &&
        error.response?.statusCode == HttpStatus.notFound) {
      Noticing.showNotice(context, S.of(context).post_does_not_exist,
          title: S.of(context).fatal_error, useSnackBar: false);
    } else {
      Noticing.showModalError(context, error, trace: st);
    }
  } finally {
    progressDialog.dismiss(showAnim: false);
  }
}

/// Submit the [value] to [searchHistory].
void submit(BuildContext context, String value) {
  value = value.trim();
  if (value.isEmpty) return;

  final history = context.read<SettingsProvider>().searchHistory;
  // Populate history
  if (!history.contains(value)) {
    context.read<SettingsProvider>().searchHistory = [value] + history;
  }
}

typedef SearchSuggestionProvider = Widget Function(
    BuildContext context, String searchKeyword);
