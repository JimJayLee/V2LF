import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/i10n/localization_intl.dart';
import 'package:flutter_app/model/sov2ex.dart';
import 'package:flutter_app/page_topic_detail.dart';
import 'package:flutter_app/resources/colors.dart';
import 'package:flutter_app/utils/sp_helper.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// @author: wml
/// @date  : 2019/4/14 10:57 PM
/// @email : mxl1989@gmail.com
/// @desc  : 搜索节点

class SearchNodeDelegate extends SearchDelegate<String> {
  final List<String> _history = SpHelper.sp.getStringList(SP_SEARCH_HISTORY) != null
      ? SpHelper.sp.getStringList(SP_SEARCH_HISTORY)
      : []; // ['v2er', 'AirPods']

  String lastQ = ""; // 上一次的搜索关键字
  Future<Sov2ex> _future; // 搜索数据 Future

  @override
  ThemeData appBarTheme(BuildContext context) {
    if (ColorT.isDark) {
      final ThemeData theme = Theme.of(context);
      return theme.copyWith(
        primaryColor: theme.primaryColor,
        primaryIconTheme: theme.primaryIconTheme,
        primaryColorBrightness: theme.primaryColorBrightness,
        primaryTextTheme: theme.primaryTextTheme,
      );
    } else {
      return super.appBarTheme(context);
    }
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(CupertinoIcons.clear_circled_solid),
        onPressed: () {
          query = "";
          showSuggestions(context);
        },
      )
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: AnimatedIcon(icon: AnimatedIcons.menu_arrow, progress: transitionAnimation),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.isEmpty) {
      return Center(child: Text('┐(´-｀)┌'));
    }

    if (!_history.contains(query.trim())) {
      _history.insert(0, query.trim());
      SpHelper.sp.setStringList(SP_SEARCH_HISTORY, _history);
    }

    if (query.trim() != lastQ) {
      _future = getSov2exData(query.trim());
      lastQ = query.trim();
    }

    return buildSearchFutureBuilder(query.trim());
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _history.isNotEmpty
        ? ListView.builder(
            itemBuilder: (context, index) {
              if (index == _history.length) {
                return _buildClearHistory(context);
              } else {
                return ListTile(
                  leading: Icon(Icons.history),
                  title: Text(_history[index]),
                  onTap: () {
                    query = _history[index];
                    showResults(context);
                  },
                );
              }
            },
            itemCount: _history.length + 1, // +1 是清空搜索记录
          )
        : Center(
            child: Text(MyLocalizations.of(context).noHistorySearch),
          );
  }

  Widget _buildClearHistory(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10.0),
      child: Center(
        child: InkWell(
          child: Text(MyLocalizations.of(context).clearHistorySearch),
          onTap: () {
            _history.clear();
            SpHelper.sp.remove(SP_SEARCH_HISTORY);
            query = "";
            showSuggestions(context);
          },
        ),
      ),
    );
  }

  FutureBuilder<Sov2ex> buildSearchFutureBuilder(String q) {
    return new FutureBuilder<Sov2ex>(
      future: _future,
      builder: (context, AsyncSnapshot<Sov2ex> async) {
        if (async.connectionState == ConnectionState.active || async.connectionState == ConnectionState.waiting) {
          return new Center(
            child: new CircularProgressIndicator(),
          );
        }

        if (async.connectionState == ConnectionState.done) {
          if (async.hasError) {
            return new Center(
              child: new Text('${async.error}'),
            );
          } else if (async.hasData) {
            Sov2ex sov2ex = async.data;
            return Sov2exResultListView(sov2ex.hits);
          }
        }
      },
    );
  }

  Future<Sov2ex> getSov2exData(String q) async {
    var dio = Dio();
    try {
      var response = await dio.get('https://www.sov2ex.com/api/search?size=50&q=' + q);
      print(response.data);
      return Sov2ex.fromMap(response.data);
    } on DioError catch (e) {
      Fluttertoast.showToast(msg: '搜索出错了...');
      print(e.response.data);
      print(e.response.headers);
      print(e.response.request);
      return null;
    }
  }
}

class Sov2exResultListView extends StatelessWidget {
  final List<HitsListBean> hits;

  Sov2exResultListView(this.hits);

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: ListView.builder(
          itemCount: hits.length,
          itemBuilder: (context, index) {
            return Sov2exResultItem(hits[index]);
          }),
    );
  }
}

class Sov2exResultItem extends StatelessWidget {
  final HitsListBean hitsListBean;

  Sov2exResultItem(this.hitsListBean);

  @override
  Widget build(BuildContext context) {
    String title = hitsListBean.highlight.title != null
        ? hitsListBean.highlight.title[0].replaceAll('<em>', '<a>').replaceAll('<\/em>', '<\/a>')
        : hitsListBean.source.title;

    String content = hitsListBean.highlight.content != null
        ? hitsListBean.highlight.content[0].replaceAll('<em>', '<a>').replaceAll('<\/em>', '<\/a>')
        : (hitsListBean.highlight.postscript_list != null
            ? hitsListBean.highlight.postscript_list[0].replaceAll('<em>', '<a>').replaceAll('<\/em>', '<\/a>')
            : (hitsListBean.highlight.reply_list != null
                ? hitsListBean.highlight.reply_list[0].replaceAll('<em>', '<a>').replaceAll('<\/em>', '<\/a>')
                : hitsListBean.source.content));

    return GestureDetector(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Html(
                  data: title,
                  defaultTextStyle: Theme.of(context).textTheme.subhead,
                  linkStyle: TextStyle(
                    color: Colors.red,
                    decoration: null,
                  ),
                ),
                SizedBox(
                  height: 8.0,
                ),
                Html(
                  data: content,
                  renderNewlines: true,
                  defaultTextStyle: TextStyle(color: ColorT.isDark ? Colors.white70 : Colors.grey[800], fontSize: 14.0),
                  linkStyle: TextStyle(
                    color: Colors.red,
                    decoration: null,
                  ),
                  useRichText: true,
                ),
                SizedBox(
                  height: 8.0,
                ),
                Text(
                  hitsListBean.source.member +
                      " 于 " +
                      hitsListBean.source.created.replaceAll('T', '  ') +
                      " 发表，共计 " +
                      hitsListBean.source.replies.toString() +
                      " 个回复",
                  style: TextStyle(color: ColorT.isDark ? Colors.white30 : Colors.black38, fontSize: 12.0),
                )
              ],
            ),
          ),
          Divider(
            height: 6.0,
          )
        ],
      ),
      onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TopicDetails(hitsListBean.source.id.toString())),
          ),
      behavior: HitTestBehavior.opaque,
    );
  }
}