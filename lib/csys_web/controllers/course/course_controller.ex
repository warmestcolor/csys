defmodule CSysWeb.CourseController do
  use CSysWeb, :controller
  use PhoenixSwagger # 注入 Swagger

  alias CSys.CourseDao
  alias CSysWeb.CourseView
  alias CSysWeb.TableView

  alias CSys.Course.ConflictProcesser

  alias CSys.Auth

  action_fallback CSysWeb.FallbackController

  swagger_path :index do
    get "/api/courses"
    description "获取全部课程"
    paging
    parameters do
      word :query, :string, "搜索关键词，可选", required: false
    end
    response 200, "success"
    response 204, "empty"
  end

  swagger_path :current_table do
    get "/api/tables/current"
    description "获取全部已选课程（当前课表）"
    response 200, "success"
    response 204, "empty"
  end

  swagger_path :table do
    get "/api/tables/history/{term_id}"
    description "获取全部课程（历史课表）"
    parameters do
      term_id :path, :integer, "学期id", required: true
    end
    response 200, "success"
    response 204, "empty"
  end

  swagger_path :chose do
    post "/api/courses/{course_id}"
    description "选课"
    parameters do
      course_id :path, :integer, "课程id", required: true
    end
    response 200, "success"
    response 204, "empty"
  end

  swagger_path :cancel do
    PhoenixSwagger.Path.delete "/api/courses/{course_id}"
    description "退课"
    parameters do
      course_id :path, :integer, "课程id", required: true
    end
    response 200, "success"
    response 204, "empty"
  end

  def index(conn, params) do
    word = params |> Dict.get("word", nil)
    page_number = params |> Dict.get("page", "1") |> String.to_integer
    page_size = params |> Dict.get("page_size", "10") |> String.to_integer

    current_term_id = CourseDao.find_current_term_id()
    current_user_id = get_session(conn, :current_user_id)

    page =
    %{
      page: page_number,
      page_size: page_size
    }
    courses = if word do
      CourseDao.list_courses_by_term(page, current_term_id, word)
      |> conflict_append(current_term_id, current_user_id)
    else
      CourseDao.list_courses_by_term(page, current_term_id)
      |> conflict_append(current_term_id, current_user_id)
    end

    conn
    |> render(CourseView, "courses_page_with_conflict.json", courses_page: courses)
  end

  defp conflict_append(course_page, term_id, user_id) do
    course_page |> IO.inspect(label: ">> courses page")
    %{
      page_number: course_page.page_number,
      page_size: course_page.page_size,
      total_entries: course_page.total_entries,
      total_pages: course_page.total_pages,
      entries: ConflictProcesser.enhance_conflict_courses(course_page.entries, term_id, user_id)
    }
  end

  def chose(conn, %{"course_id" => course_id}) do
    current_term_id = CourseDao.find_current_term_id()
    current_user_id = get_session(conn, :current_user_id)

    if Auth.can_enroll_course(current_user_id) do
      if current_term_id do
        case ConflictProcesser.judge_dup(current_user_id, current_term_id, course_id) |> IO.inspect  do
          {:ok, msg} ->
            # IO.puts(msg)
            case CourseDao.chose_course(current_user_id, current_term_id, course_id) do
              {:ok, msg} ->
                conn
                |> json(%{message: msg})
              {:error, msg} ->
                conn
                |> put_status(:bad_request)
                |> json(%{message: msg})
            end
          {:error, msg} ->
            conn
                |> put_status(:bad_request)
                |> json(%{message: msg})
        end
      else
        conn
        |> put_status(:bad_request)
        |> json(%{message: "Current Term Unset, Please contact admin."})
      end
    else
      conn |> put_status(:bad_request) |> json(%{message: "Forbidden! You can not select any course now."})
    end
  end

  def cancel(conn, %{"course_id" => course_id}) do
    current_term_id = CourseDao.find_current_term_id()
    current_user_id = get_session(conn, :current_user_id)

    if Auth.can_enroll_course(current_user_id) do
      if current_term_id do
        case CourseDao.cancel_course(current_user_id, current_term_id, course_id) do
          {:ok, msg} ->
            conn
            |> json(%{message: msg})
          {:error, msg} ->
            conn
            |> put_status(:bad_request)
            |> json(%{message: msg})
        end
      else
        conn
        |> put_status(:bad_request)
        |> json(%{message: "Current Term Unset, Please contact admin."})
      end
    else
      conn |> put_status(:bad_request) |> json(%{message: "Forbidden! You can not withdraw any course now."})
    end
  end

  #### tables ####
  def current_table(conn, _) do
    current_term_id = CourseDao.find_current_term_id()
    current_user_id = get_session(conn, :current_user_id)

    if current_term_id do
      courses = CourseDao.list_course_tables(current_term_id, current_user_id)
      conn
      |> render(TableView, "table.json", table: courses)
    else
      conn
      |> put_status(:bad_request)
      |> json(%{message: "Current Term Unset, Please contact admin."})
    end
  end

  def table(conn, %{"term_id" => term_id}) do
    current_user_id = get_session(conn, :current_user_id)

    if term_id do
      courses = CourseDao.list_course_tables(term_id, current_user_id)
      conn
      |> render(TableView, "table.json", table: courses)
    else
      conn
      |> put_status(:bad_request)
      |> json(%{message: "Current Term Unset, Please contact admin."})
    end
  end
end
