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

import 'dart:async';

import 'package:dan_xi/generated/l10n.dart';
import 'package:dan_xi/model/opentreehole/hole.dart';
import 'package:dan_xi/model/opentreehole/report.dart';
import 'package:dan_xi/page/opentreehole/hole_detail.dart';
import 'package:dan_xi/repository/opentreehole/opentreehole_repository.dart';
import 'package:dan_xi/util/browser_util.dart';
import 'package:dan_xi/util/master_detail_view.dart';
import 'package:dan_xi/util/noticing.dart';
import 'package:dan_xi/util/opentreehole/human_duration.dart';
import 'package:dan_xi/util/public_extension_methods.dart';
import 'package:dan_xi/widget/libraries/paged_listview.dart';
import 'package:dan_xi/widget/libraries/platform_app_bar_ex.dart';
import 'package:dan_xi/widget/libraries/platform_context_menu.dart';
import 'package:dan_xi/widget/libraries/top_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_progress_dialog/flutter_progress_dialog.dart';
import 'package:lazy_load_indexed_stack/lazy_load_indexed_stack.dart';

/// A list page showing the reports for administrators.
class BBSReportDetail extends StatefulWidget {
  final Map<String, dynamic>? arguments;

  const BBSReportDetail({Key? key, this.arguments}) : super(key: key);

  @override
  BBSReportDetailState createState() => BBSReportDetailState();
}

class BBSReportDetailState extends State<BBSReportDetail> {
  final PagedListViewController<OTReport> _listViewController =
      PagedListViewController();

  int _tabIndex = 0;

  /// Reload/load the (new) content and set the [_content] future.
  Future<List<OTReport>?> _loadContent(int page) =>
      OpenTreeHoleRepository.getInstance().adminGetReports(page * 10, 10);

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
        material: (_, __) =>
            MaterialScaffoldData(resizeToAvoidBottomInset: false),
        cupertino: (_, __) =>
            CupertinoPageScaffoldData(resizeToAvoidBottomInset: false),
        iosContentPadding: false,
        iosContentBottomPadding: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: PlatformAppBarX(
            title: TopController(
          controller: PrimaryScrollController.of(context),
          child: Text(S.of(context).reports),
        )),
        body: SafeArea(
            bottom: false,
            child: StatefulBuilder(
              // The builder widget updates context so that MediaQuery below can use the correct context (that is, Scaffold considered)
              builder: (context, setState) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: CupertinoSlidingSegmentedControl<int>(
                        onValueChanged: (int? value) {
                          setState(() {
                            _tabIndex = value!;
                          });
                        },
                        groupValue: _tabIndex,
                        children: ["Report", "Audit"]
                            .map((t) => Text(t))
                            .toList()
                            .asMap(),
                        // todo reformat the code
                      ),
                    ),
                    Expanded(
                      child: LazyLoadIndexedStack(index: _tabIndex, children: [
                        _buildReportPage(),
                      ]),
                    ),
                  ],
                );
              },
            )));
  }

  Widget _buildReportPage() => RefreshIndicator(
        edgeOffset: MediaQuery.of(context).padding.top,
        color: Theme.of(context).colorScheme.secondary,
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          await refreshSelf();
          await _listViewController.notifyUpdate(
              useInitialData: false, queueDataClear: false);
        },
        child: PagedListView<OTReport>(
          startPage: 0,
          pagedController: _listViewController,
          withScrollbar: true,
          scrollController: PrimaryScrollController.of(context),
          dataReceiver: _loadContent,
          builder: _getListItems,
          loadingBuilder: (BuildContext context) => Container(
            padding: const EdgeInsets.all(8),
            child: Center(child: PlatformCircularProgressIndicator()),
          ),
          endBuilder: (context) => Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(S.of(context).end_reached),
            ),
          ),
        ),
      );

  // Widget _buildAuditPage() {
  //   return
  // }

  List<Widget> _buildContextMenu(
          BuildContext pageContext, BuildContext menuContext, OTReport e) =>
      [
        PlatformContextMenuItem(
          menuContext: menuContext,
          child: const Text("Mark as dealt"),
          onPressed: () async {
            int? result = await OpenTreeHoleRepository.getInstance()
                .adminSetReportDealt(e.report_id!);
            if (result != null && result < 300 && mounted) {
              Noticing.showModalNotice(pageContext,
                  message: S.of(pageContext).operation_successful);
            }
          },
        )
      ];

  Widget _getListItems(BuildContext context,
      ListProvider<OTReport> dataProvider, int index, OTReport e) {
    void onLinkTap(String? url) {
      BrowserUtil.openUrl(url!, context);
    }

    void onImageTap(String? url, Object heroTag) {
      smartNavigatorPush(context, '/image/detail', arguments: {
        'preview_url': url,
        'hd_url': OpenTreeHoleRepository.getInstance()
            .extractHighDefinitionImageUrl(url!),
        'hero_tag': heroTag
      });
    }

    return GestureDetector(
      onLongPress: () {
        showPlatformModalSheet(
            context: context,
            builder: (BuildContext cxt) => PlatformContextMenu(
                  actions: _buildContextMenu(context, cxt, e),
                  cancelButton: CupertinoActionSheetAction(
                    child: Text(S.of(cxt).cancel),
                    onPressed: () => Navigator.of(cxt).pop(),
                  ),
                ));
      },
      child: Card(
        child: ListTile(
            dense: true,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                    alignment: Alignment.topLeft,
                    child: smartRender(
                        context, e.reason!, onLinkTap, onImageTap, false)),
                const Divider(),
                Align(
                    alignment: Alignment.topLeft,
                    child: Text(e.floor?.content ?? "?", maxLines: 5)),
              ],
            ),
            subtitle: Column(children: [
              const SizedBox(
                height: 8,
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(
                  "#${e.hole_id} (##${e.floor?.floor_id})",
                  style: TextStyle(
                      color: Theme.of(context).hintColor, fontSize: 12),
                ),
                Text(
                  HumanDuration.tryFormat(
                      context, DateTime.parse(e.time_created!)),
                  style: TextStyle(
                      color: Theme.of(context).hintColor, fontSize: 12),
                ),
                GestureDetector(
                  child: Text("Mark as dealt",
                      style: TextStyle(
                          color: Theme.of(context).hintColor, fontSize: 12)),
                  onTap: () async {
                    int? result = await OpenTreeHoleRepository.getInstance()
                        .adminSetReportDealt(e.report_id!);
                    if (result != null && result < 300 && mounted) {
                      Noticing.showModalNotice(context,
                          message: S.of(context).operation_successful);
                    }
                  },
                ),
              ]),
            ]),
            onTap: () async {
              ProgressFuture progressDialog = showProgressDialog(
                  loadingText: S.of(context).loading, context: context);
              try {
                final OTHole? post = await OpenTreeHoleRepository.getInstance()
                    .loadSpecificHole(e.hole_id!);
                if (!mounted) return;
                smartNavigatorPush(context, "/bbs/postDetail",
                    arguments: {"post": post!, "locate": e.floor});
              } catch (error, st) {
                Noticing.showErrorDialog(context, error, trace: st);
              } finally {
                progressDialog.dismiss(showAnim: false);
              }
            }),
      ),
    );
  }
}
