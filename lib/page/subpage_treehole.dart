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

import 'package:beautiful_soup_dart/beautiful_soup.dart';
import 'package:dan_xi/common/constant.dart';
import 'package:dan_xi/common/feature_registers.dart';
import 'package:dan_xi/generated/l10n.dart';
import 'package:dan_xi/model/opentreehole/division.dart';
import 'package:dan_xi/model/opentreehole/hole.dart';
import 'package:dan_xi/model/opentreehole/tag.dart';
import 'package:dan_xi/model/person.dart';
import 'package:dan_xi/page/platform_subpage.dart';
import 'package:dan_xi/provider/ad_manager.dart';
import 'package:dan_xi/provider/settings_provider.dart';
import 'package:dan_xi/provider/state_provider.dart';
import 'package:dan_xi/repository/opentreehole/opentreehole_repository.dart';
import 'package:dan_xi/util/browser_util.dart';
import 'package:dan_xi/util/human_duration.dart';
import 'package:dan_xi/util/master_detail_view.dart';
import 'package:dan_xi/util/noticing.dart';
import 'package:dan_xi/util/public_extension_methods.dart';
import 'package:dan_xi/util/scroller_fix/primary_scroll_page.dart';
import 'package:dan_xi/util/stream_listener.dart';
import 'package:dan_xi/widget/libraries/future_widget.dart';
import 'package:dan_xi/widget/libraries/paged_listview.dart';
import 'package:dan_xi/widget/libraries/platform_app_bar_ex.dart';
import 'package:dan_xi/widget/opentreehole/bbs_editor.dart';
import 'package:dan_xi/widget/opentreehole/login_widgets.dart';
import 'package:dan_xi/widget/opentreehole/treehole_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

const kCompatibleUserGroup = [
  UserGroup.FUDAN_UNDERGRADUATE_STUDENT,
  UserGroup.FUDAN_POSTGRADUATE_STUDENT,
  UserGroup.FUDAN_STAFF,
  UserGroup.SJTU_STUDENT
];

bool isHtml(String content) {
  var htmlMatcher = RegExp(r'<.+>.*</.+>', dotAll: true);
  return htmlMatcher.hasMatch(content);
}

/// Render the text from a clip of [content].
/// Also supports adding image tag to markdown posts
String renderText(String content, String imagePlaceholder) {
  if (!isHtml(content)) {
    content = md.markdownToHtml(content);
  }
  // Deal with Markdown
  content =
      content.replaceAll(RegExp(r"!\[.*\]\(http(s)?://.+\)"), imagePlaceholder);

  var soup = BeautifulSoup(content);
  var images = soup.findAll("img");
  if (images.length > 0) return soup.getText().trim() + imagePlaceholder;
  return soup.getText().trim();
}

const String KEY_NO_TAG = "默认";

class BBSSubpage extends PlatformSubpage with PageWithPrimaryScrollController {
  final Map<String, dynamic>? arguments;

  @override
  _BBSSubpageState createState() => _BBSSubpageState();

  BBSSubpage({Key? key, this.arguments});

  @override
  String get debugTag => "BBSPage";

  /// Build a list of options controlling how to sort posts.
  List<Widget> _buildDivisionOptionsList(BuildContext cxt) {
    List<Widget> list = [];
    Function onTapListener = (OTDivision newDivision) {
      Navigator.of(cxt).pop();
      DivisionChangedEvent(newDivision).fire();
    };
    OpenTreeHoleRepository.getInstance().getDivisions().forEach((value) {
      list.add(PlatformWidget(
        cupertino: (_, __) => CupertinoActionSheetAction(
          onPressed: () => onTapListener(value),
          child: Text(value.name ?? "null"),
        ),
        material: (_, __) => ListTile(
          title: Text(value.name ?? "null"),
          onTap: () => onTapListener(value),
        ),
      ));
    });
    return list;
  }

  @override
  Create<List<AppBarButtonItem>> get leading => (cxt) => [
        AppBarButtonItem(
          S.of(cxt).messages,
          Icon(CupertinoIcons.bell),
          () {
            if (OpenTreeHoleRepository.getInstance().isUserInitialized)
              smartNavigatorPush(cxt, '/bbs/messages');
          },
        )
      ];

/*  @override
  Create<List<AppBarButtonItem>> get leading => (cxt) => [
        AppBarButtonItem(
          S.of(cxt).sort_order,
          Icon(CupertinoIcons.sort_down_circle),
          () => showPlatformModalSheet(
            context: cxt,
            builder: (BuildContext context) => PlatformWidget(
              cupertino: (_, __) => CupertinoActionSheet(
                title: Text(S.of(cxt).sort_order),
                actions: _buildDivisionOptionsList(context),
                cancelButton: CupertinoActionSheetAction(
                  child: Text(S.of(context).cancel),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
              material: (_, __) => Column(
                mainAxisSize: MainAxisSize.min,
                children: _buildDivisionOptionsList(context),
              ),
            ),
          ),
        )
      ]; */

  @override
  Create<String> get title => (cxt) => S.of(cxt).forum;

  @override
  Create<List<AppBarButtonItem>> get trailing => (cxt) => [
        AppBarButtonItem(S.of(cxt).all_tags, Icon(PlatformIcons(cxt).tag), () {
          if (OpenTreeHoleRepository.getInstance().isUserInitialized)
            smartNavigatorPush(cxt, '/bbs/tags');
        }),
        AppBarButtonItem(S.of(cxt).favorites, Icon(CupertinoIcons.star), () {
          if (OpenTreeHoleRepository.getInstance().isUserInitialized)
            smartNavigatorPush(cxt, '/bbs/discussions', arguments: {
              'showFavoredDiscussion': true,
            });
        }),
        AppBarButtonItem(
            S.of(cxt).new_post, Icon(PlatformIcons(cxt).addCircled), () {
          if (OpenTreeHoleRepository.getInstance().isUserInitialized)
            AddNewPostEvent().fire();
        }),
      ];
}

class AddNewPostEvent {}

class RefreshBBSEvent {
  final bool refreshAll;

  RefreshBBSEvent({this.refreshAll = false});
}

class DivisionChangedEvent {
  final OTDivision newDivision;

  DivisionChangedEvent(this.newDivision);
}

enum PostsType { FAVORED_DISCUSSION, FILTER_BY_TAG, NORMAL_POSTS }

/// A list page showing bbs posts.
///
/// Arguments:
/// [bool] showFavoredDiscussion: if [showFavoredDiscussion] is not null,
/// it means this page is showing user's favored posts.
/// [String] tagFilter: if [tagFilter] is not null, it means this page is showing
/// the posts which is tagged with [tagFilter].
///
class _BBSSubpageState extends State<BBSSubpage>
    with AutomaticKeepAliveClientMixin {
  /// Unrelated to the state.
  /// These field should only be initialized once when created.
  final StateStreamListener _postSubscription = StateStreamListener();
  final StateStreamListener _refreshSubscription = StateStreamListener();
  final StateStreamListener _searchSubscription = StateStreamListener();
  final StateStreamListener _divisionChangedSubscription =
      StateStreamListener();
  String? _tagFilter;
  FocusNode _searchFocus = FocusNode();
  PostsType _postsType = PostsType.NORMAL_POSTS;

  final PagedListViewController<OTHole> _listViewController =
      PagedListViewController();

  final TimeBasedLoadAdaptLayer<OTHole> adaptLayer =
      new TimeBasedLoadAdaptLayer(10, 1);

  /// Fields related to the display states.
  int _divisionId = 1;

  FoldBehavior? get foldBehavior => foldBehaviorFromInternalString(
      OpenTreeHoleRepository.getInstance().userInfo?.config?.show_folded);

  BannerAd? bannerAd;

  /// This is to prevent the entire page being rebuilt on iOS when the keyboard pops up
  late bool _fieldInitComplete;

  ///Set the Future of the page when the framework calls build(), the content is not reloaded every time.
  Future<List<OTHole>?> _loadContent(int page) async {
    if (!checkGroup(kCompatibleUserGroup))
      throw NotLoginError("Logged in as a visitor.");

    // Initialize the user token from shared preferences.
    // If no token, NotLoginError will be thrown.
    if (!OpenTreeHoleRepository.getInstance().isUserInitialized)
      await OpenTreeHoleRepository.getInstance().initializeRepo();

    switch (_postsType) {
      case PostsType.FAVORED_DISCUSSION:
        if (page > 1) return Future.value([]);
        return await OpenTreeHoleRepository.getInstance().getFavoriteHoles();
      case PostsType.FILTER_BY_TAG:
      case PostsType.NORMAL_POSTS:
        List<OTHole>? loadedPost = await adaptLayer
            .generateReceiver(_listViewController, (lastElement) {
          DateTime time;
          if (lastElement != null) {
            time = DateTime.parse(lastElement.time_updated!);
          } else
            time = DateTime.now();
          return OpenTreeHoleRepository.getInstance()
              .loadHoles(time, _divisionId, tag: _tagFilter);
        }).call(page);
        // Filter blocked posts
        List<OTTag> hiddenTags =
            SettingsProvider.getInstance().hiddenTags ?? [];
        loadedPost?.removeWhere((element) => element.tags!.any((thisTag) =>
            hiddenTags.any((blockTag) => thisTag.name == blockTag.name)));

        // About this line, see [PagedListView].
        return loadedPost == null || loadedPost.isEmpty
            ? [OTHole.DUMMY_POST]
            : loadedPost;
    }
  }

  Future<void> refreshSelf() async {
    if (_postsType == PostsType.FAVORED_DISCUSSION) {
      await OpenTreeHoleRepository.getInstance()
          .getFavoriteHoleId(forceUpdate: true);
    }
    if (OpenTreeHoleRepository.getInstance().isUserInitialized)
      await OpenTreeHoleRepository.getInstance().loadDivisions(useCache: false);
    await _listViewController.notifyUpdate();
  }

  Widget _autoAdminNotice() {
    {
      if (OpenTreeHoleRepository.getInstance().isAdmin) {
        return Card(
          child: ListTile(
            title: Text("FDUHole Administrative Interface"),
            subtitle: Text(
              "Status: Authorized",
              style: TextStyle(color: Colors.green),
            ),
            onTap: () {
              smartNavigatorPush(context, "/bbs/reports");
            },
          ),
        );
      }
    }
    return const SizedBox();
  }

  Widget _autoSilenceNotice() {
    final DateTime? silenceDate = OpenTreeHoleRepository.getInstance()
        .getSilenceDateForDivision(_divisionId);
    if (silenceDate == null || silenceDate.isBefore(DateTime.now()))
      return const SizedBox();
    return Card(
      child: ListTile(
        leading: Icon(
          CupertinoIcons.exclamationmark_triangle,
          color: Theme.of(context).errorColor,
        ),
        title: Text(
          S.of(context).silence_notice,
          style: TextStyle(color: Theme.of(context).errorColor),
        ),
        subtitle: Text(
          S.of(context).ban_post_until(
              "${silenceDate.year}-${silenceDate.month}-${silenceDate.day} ${silenceDate.hour}:${silenceDate.minute}"),
        ),
        onTap: () {
          Noticing.showNotice(context, S.of(context).silence_detail,
              title: S.of(context).silence_notice, useSnackBar: false);
        },
      ),
    );
  }

  Widget _autoPinnedPosts() {
    return Column(
      children: OpenTreeHoleRepository.getInstance()
          .getPinned(_divisionId)
          .map((e) => _buildListItem(context, null, null, e, isPinned: true))
          .toList(),
    );
  }

  @override
  void initState() {
    super.initState();
    _fieldInitComplete = false;
    _postSubscription.bindOnlyInvalid(
        Constant.eventBus.on<AddNewPostEvent>().listen((_) async {
          final bool success =
              await BBSEditor.createNewPost(context, _divisionId);
          if (success) refreshSelf();
        }),
        hashCode);
    _refreshSubscription.bindOnlyInvalid(
        Constant.eventBus.on<RefreshBBSEvent>().listen((event) {
          if (event.refreshAll == true) {
            _refreshAll();
          } else
            refreshSelf();
        }),
        hashCode);
    _divisionChangedSubscription.bindOnlyInvalid(
        Constant.eventBus.on<DivisionChangedEvent>().listen((event) {
          if (event.newDivision.division_id != _divisionId) {
            _divisionId = event.newDivision.division_id!;
            refreshSelf();
          }
          //SettingsProvider.getInstance().fduholeSortOrder = _sortOrder = event.newDivision;
        }),
        hashCode);
    bannerAd = AdManager.loadBannerAd(1); // 1 for bbs page
  }

  void _refreshAll() {
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    if (!_fieldInitComplete) {
      if (widget.arguments?.containsKey('tagFilter') ?? false)
        _tagFilter = widget.arguments!['tagFilter'];
      if (_tagFilter != null) {
        _postsType = PostsType.FILTER_BY_TAG;
      } else if (widget.arguments?.containsKey('showFavoredDiscussion') ??
          false) {
        _postsType = PostsType.FAVORED_DISCUSSION;
      }
      _fieldInitComplete = true;
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    super.dispose();
    _postSubscription.cancel();
    _refreshSubscription.cancel();
    _searchSubscription.cancel();
    _divisionChangedSubscription.cancel();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    switch (_postsType) {
      case PostsType.FAVORED_DISCUSSION:
        return PlatformScaffold(
          iosContentPadding: false,
          iosContentBottomPadding: false,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: PlatformAppBarX(
            title: Text(S.of(context).favorites),
          ),
          body: _buildPageBody(),
        );
      case PostsType.FILTER_BY_TAG:
        return PlatformScaffold(
          iosContentPadding: false,
          iosContentBottomPadding: false,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: PlatformAppBarX(
            title: Text(S.of(context).filtering_by_tag(_tagFilter ?? "?")),
          ),
          body: _buildPageBody(),
        );
      case PostsType.NORMAL_POSTS:
        return _buildPageBody();
    }
  }

  Widget _buildPageBody() {
    return Material(
      child: Container(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: Theme.of(context).accentColor,
            backgroundColor: Theme.of(context).dialogBackgroundColor,
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              await refreshSelf();
            },
            child: PagedListView<OTHole>(
                noneItem: OTHole.DUMMY_POST,
                pagedController: _listViewController,
                withScrollbar: true,
                scrollController: widget.primaryScrollController(context),
                startPage: 1,
                builder: _buildListItem,
                headBuilder: (_) => Column(
                      children: [
                        AutoBannerAdWidget(bannerAd: bannerAd),
                        if (_postsType == PostsType.NORMAL_POSTS) ...[
                          OTSearchWidget(
                            focusNode: _searchFocus,
                          ),
                          _autoSilenceNotice(),
                          _autoAdminNotice(),
                          _autoPinnedPosts(),
                        ],
                      ],
                    ),
                loadingBuilder: (BuildContext context) => Container(
                      padding: EdgeInsets.all(8),
                      child: Center(child: PlatformCircularProgressIndicator()),
                    ),
                endBuilder: (context) => Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(S.of(context).end_reached),
                      ),
                    ),
                emptyBuilder: (_) {
                  if (_postsType == PostsType.FAVORED_DISCUSSION)
                    return _buildEmptyFavoritesPage();
                  else
                    return Container(
                      padding: EdgeInsets.all(8),
                      child: Center(child: Text(S.of(context).no_data)),
                    );
                },
                fatalErrorBuilder: (_, e) {
                  if (e is NotLoginError) {
                    return OTWelcomeWidget(loginCallback: () async {
                      await smartNavigatorPush(context, "/bbs/login",
                          arguments: {"info": StateProvider.personInfo.value!});
                      refreshSelf();
                    });
                  }
                  return const SizedBox();
                },
                dataReceiver: _loadContent),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFavoritesPage() => Container(
        padding: EdgeInsets.all(8),
        child: Center(child: Text(S.of(context).no_favorites)),
      );

  _launchUrlWithNotice(LinkableElement link) async {
    if (await canLaunch(link.url)) {
      BrowserUtil.openUrl(link.url, context);
    } else {
      Noticing.showNotice(context, S.of(context).cannot_launch_url);
    }
  }

  Widget _buildListItem(BuildContext context, ListProvider<OTHole>? _, int? __,
      OTHole postElement,
      {bool isPinned = false}) {
    if (postElement.floors?.first_floor == null ||
        postElement.floors?.last_floor == null ||
        (foldBehavior == FoldBehavior.HIDE && postElement.is_folded))
      return const SizedBox();
    Linkify postContentWidget = Linkify(
      text: renderText(postElement.floors!.first_floor!.filteredContent!,
          S.of(context).image_tag),
      style: TextStyle(fontSize: 16),
      maxLines: 6,
      overflow: TextOverflow.ellipsis,
      onOpen: _launchUrlWithNotice,
    );
    final TextStyle infoStyle =
        TextStyle(color: Theme.of(context).hintColor, fontSize: 12);

    return Card(
      child: Column(
        children: [
          ListTile(
              contentPadding: EdgeInsets.fromLTRB(16, 4, 10, 0),
              dense: false,
              title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        generateTagWidgets(context, postElement,
                            (String? tagname) {
                          smartNavigatorPush(context, '/bbs/discussions',
                              arguments: {"tagFilter": tagname});
                        },
                            SettingsProvider.getInstance()
                                .useAccessibilityColoring),
                        if (isPinned)
                          OTLeadingTag(
                            colorString: 'blue',
                            text: S.of(context).pinned,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    (postElement.is_folded && foldBehavior == FoldBehavior.FOLD)
                        ? Theme(
                            data: Theme.of(context)
                                .copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                                expandedCrossAxisAlignment:
                                    CrossAxisAlignment.start,
                                expandedAlignment: Alignment.topLeft,
                                childrenPadding:
                                    EdgeInsets.symmetric(vertical: 4),
                                tilePadding: EdgeInsets.zero,
                                title: Text(
                                  S.of(context).folded,
                                  style: infoStyle,
                                ),
                                children: [
                                  postContentWidget,
                                ]))
                        : postContentWidget,
                  ]),
              subtitle: Column(children: [
                const SizedBox(height: 12),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("#${postElement.hole_id}", style: infoStyle),
                      Text(
                          HumanDuration.tryFormat(context,
                              DateTime.parse(postElement.time_created!)),
                          style: infoStyle),
                      Row(children: [
                        /*Text("${postElement.view} ", style: infoStyle),
                        Icon(CupertinoIcons.eye,
                            size: infoStyle.fontSize, color: infoStyle.color),
                        const SizedBox(width: 4),*/
                        Text("${postElement.reply} ", style: infoStyle),
                        Icon(CupertinoIcons.ellipses_bubble,
                            size: infoStyle.fontSize, color: infoStyle.color),
                      ]),
                    ]),
              ]),
              onTap: () {
                smartNavigatorPush(context, "/bbs/postDetail", arguments: {
                  "post": postElement,
                });
              }),
          if (!(postElement.is_folded && foldBehavior == FoldBehavior.FOLD) &&
              postElement.floors?.last_floor !=
                  postElement.floors?.first_floor) ...[
            Divider(height: 4),
            _buildCommentView(postElement)
          ]
        ],
      ),
    );
  }

  Widget _buildCommentView(OTHole postElement, {bool useLeading = true}) {
    final String lastReplyContent = renderText(
        postElement.floors!.last_floor!.filteredContent!,
        S.of(context).image_tag);
    return ListTile(
        dense: true,
        minLeadingWidth: 16,
        leading: useLeading
            ? Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(
                  CupertinoIcons.quote_bubble,
                  color: Theme.of(context).hintColor,
                ),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(0, 8, 0, 4),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      S.of(context).latest_reply(
                          postElement.floors!.last_floor!.anonyname ?? "?",
                          HumanDuration.tryFormat(
                              context,
                              DateTime.parse(postElement
                                  .floors!.last_floor!.time_created!))),
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                    Icon(CupertinoIcons.search,
                        size: 14,
                        color: Theme.of(context).hintColor.withOpacity(0.2)),
                  ]),
            ),
            Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Linkify(
                    text: lastReplyContent.trim().isEmpty
                        ? S.of(context).no_summary
                        : lastReplyContent,
                    style: TextStyle(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    onOpen: _launchUrlWithNotice)),
          ],
        ),
        onTap: () => smartNavigatorPush(context, "/bbs/postDetail",
            arguments: {"post": postElement, "scroll_to_end": true}));
  }

  @override
  bool get wantKeepAlive => true;
}

/// This class is a workaround between Open Tree Hole's time-based content retrieval style
/// and [PagedListView]'s page-based loading style.
class TimeBasedLoadAdaptLayer<T> {
  final int pageSize;
  final int startPage;

  TimeBasedLoadAdaptLayer(this.pageSize, this.startPage);

  DataReceiver<T> generateReceiver(PagedListViewController<T> controller,
      TimeBasedDataReceiver<T> receiver) {
    return (int pageIndex) async {
      int nextPageEnd = pageSize * (pageIndex - startPage + 1);
      if (controller.length() == 0 || pageIndex == startPage) {
        // If this is the first page, call with nothing.
        return receiver.call(null);
      } else if (nextPageEnd < controller.length()) {
        // If this is not the first page, and we have loaded far more than [pageIndex],
        // we should loaded it again with the last item of previous page.
        return receiver
            .call(controller.getElementAt(nextPageEnd - startPage - 1));
      } else {
        // If requesting a brand new page, just loaded it with info of the last item.
        return receiver.call(controller.getElementAt(controller.length() - 1));
      }
    };
  }
}

typedef TimeBasedDataReceiver<T> = Future<List<T>?> Function(T? lastElement);
