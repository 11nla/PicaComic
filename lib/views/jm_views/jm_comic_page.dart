import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/jm_network/jm_image.dart';
import 'package:pica_comic/views/jm_views/jm_comments_page.dart';
import 'package:pica_comic/views/jm_views/jm_search_page.dart';
import 'package:pica_comic/views/jm_views/jm_widgets.dart';
import 'package:pica_comic/views/jm_views/show_error.dart';
import 'package:pica_comic/views/reader/comic_reading_page.dart';
import 'package:pica_comic/views/reader/goto_reader.dart';
import 'package:pica_comic/views/widgets/pop_up_widget.dart';
import 'package:share_plus/share_plus.dart';
import '../../jm_network/jm_models.dart';
import '../../tools/ui_mode.dart';
import '../models/history.dart';
import '../show_image_page.dart';
import '../widgets/loading.dart';
import '../widgets/selectable_text.dart';
import '../widgets/widgets.dart';

class JmComicPageLogic extends GetxController {
  bool loading = true;
  JmComicInfo? comic;
  String? message;
  var controller = ScrollController();
  bool showAppbarTitle = false;

  void change() {
    loading = !loading;
    update();
  }

  void getInfo(String id) async {
    var res = await jmNetwork.getComicInfo(id);
    if (res.error) {
      message = res.errorMessage;
      change();
    } else {
      comic = res.data;
      change();
    }

    //添加历史记录
    var history = NewHistory(
        HistoryType.jmComic,
        DateTime.now(),
        comic!.name,
        comic!.author[0],
        getJmCoverUrl(id),
        0,
        0,
        id
    );
    appdata.history.addHistory(history);
  }

  void retry() {
    comic = null;
    message = null;
    loading = true;
    update();
  }
}

class JmComicPage extends StatelessWidget {
  const JmComicPage(this.id, {Key? key}) : super(key: key);
  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GetBuilder<JmComicPageLogic>(
        init: JmComicPageLogic(),
        tag: id,
        builder: (logic) {
          if (logic.loading) {
            logic.getInfo(id);
            return showLoading(context);
          } else if (logic.comic == null) {
            return showNetworkError(logic.message!, logic.retry, context);
          } else {
            logic.controller.addListener(() {
              //检测当前滚动位置, 决定是否显示Appbar的标题
              bool temp = logic.showAppbarTitle;
              logic.showAppbarTitle = logic.controller.position.pixels >
                  boundingTextSize(logic.comic!.name, const TextStyle(fontSize: 22),
                              maxWidth: MediaQuery.of(context).size.width)
                          .height +
                      50;
              if (temp != logic.showAppbarTitle) {
                logic.update();
              }
            });

            return CustomScrollView(
              controller: logic.controller,
              slivers: [
                SliverAppBar(
                  surfaceTintColor: logic.showAppbarTitle ? null : Colors.transparent,
                  shadowColor: Colors.transparent,
                  title: AnimatedOpacity(
                    opacity: logic.showAppbarTitle ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Text(logic.comic!.name),
                  ),
                  pinned: true,
                  actions: [
                    Tooltip(
                      message: "分享",
                      child: IconButton(
                        icon: const Icon(
                          Icons.share,
                        ),
                        onPressed: () {
                          Share.share("Jm$id: ${logic.comic!.name}");
                        },
                      ),
                    )
                  ],
                ),

                //标题
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 20, 10, 15),
                    child: SizedBox(
                      width: double.infinity,
                      child: SelectableTextCN(
                        text: logic.comic!.name,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                ),

                buildComicInfo(context, logic),

                //简介
                const SliverPadding(padding: EdgeInsets.all(5)),
                const SliverToBoxAdapter(
                  child: Divider(),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                      width: 100,
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                          ),
                          Icon(Icons.insert_drive_file,
                              color: Theme.of(context).colorScheme.secondary),
                          const SizedBox(
                            width: 20,
                          ),
                          const Text(
                            "简介",
                            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                          )
                        ],
                      )),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 0, 0),
                    child: SelectableTextCN(text: logic.comic!.description),
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.all(5)),

                //章节显示
                ...buildChapterDisplay(context, logic),

                //相关推荐
                const SliverToBoxAdapter(
                  child: Divider(),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                      width: 100,
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                          ),
                          Icon(Icons.recommend, color: Theme.of(context).colorScheme.secondary),
                          const SizedBox(
                            width: 20,
                          ),
                          const Text(
                            "相关推荐",
                            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                          )
                        ],
                      )),
                ),
                const SliverPadding(padding: EdgeInsets.all(5)),
                SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                      childCount: logic.comic!.relatedComics.length, (context, i) {
                    return JmComicTile(logic.comic!.relatedComics[i]);
                  }),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: comicTileMaxWidth,
                    childAspectRatio: comicTileAspectRatio,
                  ),
                ),
                SliverPadding(padding: MediaQuery.of(context).padding),
              ],
            );
          }
        },
      ),
    );
  }

  Size boundingTextSize(String text, TextStyle style,
      {int maxLines = 2 ^ 31, double maxWidth = double.infinity}) {
    if (text.isEmpty) {
      return Size.zero;
    }
    final TextPainter textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(text: text, style: style),
        maxLines: maxLines)
      ..layout(maxWidth: maxWidth);
    return textPainter.size;
  }

  Widget buildCover(BuildContext context, double height, double width, JmComicPageLogic logic) {
    return GestureDetector(
      onTap: () => Get.to(() => ShowImagePage(
            getJmCoverUrl(logic.comic!.id),
          )),
      child: Padding(
          padding: const EdgeInsets.fromLTRB(25, 0, 25, 0),
          child: CachedNetworkImage(
            width: width - 50,
            height: height,
            imageUrl: getJmCoverUrl(logic.comic!.id),
            fit: BoxFit.contain,
            errorWidget: (context, url, error) => const Icon(Icons.error),
          )),
    );
  }

  List<Widget> buildInfoCards(JmComicPageLogic logic, BuildContext context) {
    var res = <Widget>[];
    var res2 = <Widget>[];

    res.add(const Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Text("作者"),
    ));
    res.add(Wrap(
      children: List.generate(logic.comic!.author.length,
          (index) => buildInfoCard(logic.comic!.author[index], context)),
    ));
    res.add(const Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Text("ID"),
    ));
    res.add(buildInfoCard("Jm${logic.comic!.id}", context, allowSearch: false));
    res.add(const Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Text("views"),
    ));
    res.add(buildInfoCard("${logic.comic!.views}", context));
    res.add(const Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Text("tags"),
    ));
    res.add(Wrap(
      children: List.generate(
          logic.comic!.tags.length, (index) => buildInfoCard(logic.comic!.tags[index], context)),
    ));
    res2.add(Padding(
      padding: const EdgeInsets.fromLTRB(10, 15, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: ActionChip(
              label: Text(logic.comic!.likes.toString()),
              avatar: logic.comic!.liked
                  ? const Icon(Icons.favorite)
                  : const Icon(Icons.favorite_outline),
              onPressed: () {
                if (logic.comic!.liked) {
                  showMessage(context, "已经喜欢了");
                  return;
                }
                jmNetwork.likeComic(logic.comic!.id);
                logic.comic!.liked = true;
                logic.update();
              },
            ),
          ),
          SizedBox.fromSize(
            size: const Size(10, 1),
          ),
          Expanded(
            child: ActionChip(
                label: const Text("收藏"),
                avatar: logic.comic!.favorite
                    ? const Icon(Icons.bookmark)
                    : const Icon(Icons.bookmark_outline),
                onPressed: () {
                  if(logic.comic!.favorite){
                    showMessage(Get.context, "正在取消收藏");
                    jmNetwork.favorite(id).then((v){
                      logic.comic!.favorite = false;
                      logic.update();
                      hideMessage(Get.context);
                    });
                  }else {
                    showDialog(context: context, builder: (context){
                      return FavoriteComicDialog(id, logic);
                  });
                  }
                }),
          ),
          SizedBox.fromSize(
            size: const Size(10, 1),
          ),
          Expanded(
            child: ActionChip(
                label: const Text("评论"),
                avatar: const Icon(Icons.comment_outlined),
                onPressed: () => showAdaptiveWidget(context, JmCommentsPage(id))),
          ),
        ],
      ),
    ));
    res2.add(Padding(
      padding: const EdgeInsets.fromLTRB(10, 15, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: () => downloadComic(logic.comic!, context),
              child: const Text("下载"),
            ),
          ),
          SizedBox.fromSize(
            size: const Size(10, 1),
          ),
          Expanded(
            child: FilledButton(
              onPressed: () => readJmComic(id, logic.comic!.name, logic.comic!.series.values.toList()),
              child: const Text("阅读"),
            ),
          ),

        ],
      ),
    ));
    return !UiMode.m1(context)?res+res2:res2+res;
  }

  Widget buildInfoCard(String title, BuildContext context, {bool allowSearch = true}) {
    return GestureDetector(
      onLongPressStart: (details) {
        showMenu(
            context: context,
            position: RelativeRect.fromLTRB(details.globalPosition.dx, details.globalPosition.dy,
                details.globalPosition.dx, details.globalPosition.dy),
            items: [
              PopupMenuItem(
                child: const Text("复制"),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: (title)));
                  showMessage(context, "已复制");
                },
              ),
              PopupMenuItem(
                child: const Text("添加到屏蔽词"),
                onTap: () {
                  appdata.blockingKeyword.add(title);
                  appdata.writeData();
                },
              ),
            ]);
      },
      onSecondaryTapUp: (details) {
        showMenu(
            context: context,
            position: RelativeRect.fromLTRB(details.globalPosition.dx, details.globalPosition.dy,
                details.globalPosition.dx, details.globalPosition.dy),
            items: [
              PopupMenuItem(
                child: const Text("复制"),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: (title)));
                  showMessage(context, "已复制");
                },
              ),
              PopupMenuItem(
                child: const Text("添加到屏蔽词"),
                onTap: () {
                  appdata.blockingKeyword.add(title);
                  appdata.writeData();
                },
              ),
            ]);
      },
      child: Card(
        margin: const EdgeInsets.fromLTRB(5, 5, 5, 5),
        elevation: 0,
        color: Theme.of(context).colorScheme.primaryContainer,
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          onTap: allowSearch
              ? () => Get.to(() => JmSearchPage(title), preventDuplicates: false)
              : () {},
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
            child: Text(title),
          ),
        ),
      ),
    );
  }

  Widget buildComicInfo(BuildContext context, JmComicPageLogic logic) {
    if (UiMode.m1(context)) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: SizedBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                //封面
                buildCover(context, 350, MediaQuery.of(context).size.width, logic),
                const SizedBox(
                  height: 20,
                ),
                ...buildInfoCards(logic, context),
              ],
            ),
          ),
        ),
      );
    } else {
      return SliverToBoxAdapter(
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Row(
            children: [
              //封面
              SizedBox(
                child: Column(
                  children: [
                    buildCover(context, 450, MediaQuery.of(context).size.width / 2, logic),
                  ],
                ),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width / 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...buildInfoCards(logic, context),
                  ],
                ),
              )
            ],
          ),
        ),
      );
    }
  }

  List<Widget> buildChapterDisplay(BuildContext context, JmComicPageLogic logic) {
    return [
      const SliverToBoxAdapter(
        child: Divider(),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
            width: 100,
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                ),
                Icon(Icons.library_books, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(
                  width: 20,
                ),
                const Text(
                  "章节",
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                )
              ],
            )),
      ),
      const SliverPadding(padding: EdgeInsets.all(5)),
      SliverGrid(
        delegate: SliverChildBuilderDelegate(childCount: logic.comic!.series.length, (context, i) {
          return Padding(
            padding: const EdgeInsets.all(1),
            child: GestureDetector(
              child: Card(
                elevation: 1,
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Center(
                  child: Text("第${i + 1}章"),
                ),
              ),
              onTap: () {
                Get.to(() => ComicReadingPage.jmComic(logic.comic!.id,
                    logic.comic!.name, logic.comic!.series.values.toList(), i+1));
              },
            ),
          );
        }),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 250,
          childAspectRatio: 4,
        ),
      ),
      if (logic.comic!.series.isEmpty) const SliverPadding(padding: EdgeInsets.all(20))
    ];
  }
}

class FavoriteComicDialog extends StatefulWidget {
  const FavoriteComicDialog(this.id, this.logic, {Key? key}) : super(key: key);
  final String id;
  final JmComicPageLogic logic;

  @override
  State<FavoriteComicDialog> createState() => _FavoriteComicDialogState();
}

class _FavoriteComicDialogState extends State<FavoriteComicDialog> {
  bool loading = true;
  Map<String, String> folders = {};
  String? message;
  String folderName = "全部收藏";
  String folderId = "0";
  bool loading2 = false;
  bool addedFavorite = false;

  @override
  Widget build(BuildContext context) {
    if(loading){
      get();
    }
    return SimpleDialog(
      title: const Text("收藏漫画"),
      children: [
        if(loading)
          const SizedBox(
            key: Key("0"),
            width: 300,
            height: 150,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else if(message != null)
          SizedBox(
            key: const Key("1"),
            width: 300,
            height: 150,
            child: Center(
              child: Text(message!),
            ),
          )
        else
          SizedBox(
            key: const Key("2"),
            width: 300,
            height: 150,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.all(5),
                  width: 300,
                  height: 50,
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: const BorderRadius.all(Radius.circular(16))
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Text("  选择收藏夹:  "),
                      Text(folderName),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.arrow_drop_down_sharp),
                        onPressed: (){
                          if(loading){
                            showMessage(context, "加载中");
                            return;
                          }
                          showMenu(
                              context: context,
                              position: RelativeRect.fromLTRB(
                                  MediaQuery.of(context).size.width/2+150,
                                  MediaQuery.of(context).size.height/2,
                                  MediaQuery.of(context).size.width/2-150,
                                  MediaQuery.of(context).size.height/2),
                              items: [
                                PopupMenuItem(
                                  child: const Text("全部收藏"),
                                  onTap: (){
                                    setState(() {
                                      folderName = "全部收藏";
                                    });
                                    folderId = "0";
                                  },
                                ),
                                for(var folder in folders.entries)
                                  PopupMenuItem(
                                    child: Text(folder.value),
                                    onTap: (){
                                      setState(() {
                                        folderName = folder.value;
                                      });
                                      folderId = folder.key;
                                    },
                                  )
                              ]
                          );
                        },
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20,),
                if(!loading2)
                  FilledButton(onPressed: () async{
                    setState(() {
                      loading2 = true;
                    });
                    if(!addedFavorite) {
                      var res = await jmNetwork.favorite(widget.id);
                      if (res.error) {
                        showMessage(Get.context, res.errorMessage!);
                        setState(() {
                          loading2 = false;
                        });
                        return;
                      }
                    }
                    addedFavorite = true;
                    if(folderId != "0") {
                      var res2 = await jmNetwork.moveToFolder(widget.id, folderId);
                      if (res2.error) {
                        showMessage(Get.context, res2.errorMessage!);
                        setState(() {
                          loading2 = false;
                        });
                        return;
                      }
                    }
                    Get.back();
                    widget.logic.comic!.favorite = true;
                    widget.logic.update();
                    showMessage(Get.context, "添加成功");
                  }, child: const Text("提交"))
                else
                  const Center(
                    child: CircularProgressIndicator(),
                  )
              ],
            ),
          )
      ],
    );
  }

  void get() async{
    var r = await jmNetwork.getFolders();
    if(r.error){
      message = r.errorMessage;
    }else{
      folders = r.data;
    }
    setState(() {
      loading = false;
    });
  }
}

void downloadComic(JmComicInfo comic, BuildContext context){
  if(GetPlatform.isWeb){
    showMessage(context, "Web端不支持下载");
    return;
  }
  if(downloadManager.downloadedJmComics.contains(comic.id)){
    showMessage(context, "已下载");
    return;
  }
  for(var i in downloadManager.downloading){
    if(i.id == comic.id){
      showMessage(context, "下载中");
      return;
    }
  }
  downloadManager.addJmDownload(comic);
  showMessage(context, "已加入下载队列");
}