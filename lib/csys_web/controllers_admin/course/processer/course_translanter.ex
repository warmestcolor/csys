defmodule CSys.CourseTranslanter do

  alias CSys.CourseProcesser
  alias CSys.CourseDao
  alias CSys.CourseTranslanter

  # @total_courses_file_name "/Users/neo/Desktop/course/total.xlsx"
  # @total_courses_file_name "/root/resources/total.xlsx"
  @doc """
  query = from c in CSys.Course.Course, where: c.inserted_at > ~N[2018-09-04 01:31:26.040675]
  query |> CSys.Repo.all
  """
  @doc """
  CSys.Course.Table |> CSys.Repo.delete_all
  CSys.Course.Course |> CSys.Repo.delete_all
  CSys.Course.Course |> CSys.CourseDao.where([inserted_at > NaiveDateTime.utc_now] ) |> CSys.Repo.all
  CSys.CourseTranslanter.translant("/Users/neo/Desktop/course/zh.xlsx", "/Users/neo/Desktop/course/total.xlsx")
  CSys.CourseTranslanter.translant("/root/resources/zh.xlsx", "/root/resources/total.xlsx")
  CSys.CourseDao.update_course_name("ME484", "New Energy Technologies: Bioenergy Engineering")
  CSys.CourseDao.update_course_name("SS040", "The Anthropology of Kinship and Family")
  CSys.CourseTranslanter.translant("/root/resources/append_1.xlsx", "/root/resources/total.xlsx")
  CSys.CourseTranslanter.translant("/Users/neo/Desktop/course/append_1.xlsx", "/Users/neo/Desktop/course/total.xlsx")
  """
  def translant(term_id, file_name, total_courses_file_name) do
    courses = Excelion.parse!(file_name, 0, 4)

    total_courses =
    Excelion.parse!(total_courses_file_name, 0, 4)
    |> Enum.map(fn line ->
      # 只需要 code 和 name
      %{
        code: line |> at(0) |> String.trim,
        en_name: line |> at(1) |> String.trim
      }
    end)

    result =
    courses
    |> Enum.map(fn line ->
      line |> IO.inspect
      code = line |> at(0) |> CourseProcesser.to_string()
      %{
        term_id: term_id,
        code: code,
        name: line |> at(1) |> en_name(code, total_courses) |> String.trim,
        class_name: line |> at(2) |> CourseTranslanter.Dictor.group() |> String.trim,
        group_name: line |> at(3) |> CourseProcesser.to_string() |> String.trim,
        compus: line |> at(4) |> CourseProcesser.to_string(),
        unit: line |> at(5) |> CourseTranslanter.Dictor.unit() |> String.trim,
        time: line |> at(6) |> CourseProcesser.to_integer(),
        credit: line |> at(7) |> CourseProcesser.to_float(),
        property: line |> at(8) |> CourseProcesser.to_string() |> property_en() |> String.trim,
        teacher: line |> at(9) |> CourseTranslanter.Dictor.teacher(),
        seat_num: line |> at(12) |> CourseProcesser.to_integer(),
        limit_num: line |> at(13) |> CourseProcesser.to_integer(),
        current_num: line |> at(14) |> CourseProcesser.to_integer(),
        notification_cate: line |> at(15) |> CourseProcesser.to_string(),
        suzhi_cate: line |> at(16) |> CourseProcesser.to_string(),
        gender_req: line |> at(17) |> CourseProcesser.to_string(),
        is_stop: line |> at(18) |> CourseProcesser.convert_boolean(),
        is_active: line |> at(19) |> CourseProcesser.convert_boolean(),
        venue: CourseProcesser.convert(line |> at(10), line |> at(11) |> CourseTranslanter.Dictor.location_detail())
      }
      |> IO.inspect
      |> CourseDao.create_course()
    end)
    |> Enum.filter(fn x ->
      {status, _} = x
      status != :ok
    end)
    IO.puts("======= Fail count: #{result |> length()} =======")
  end

  defp at(list, index) do
    {value, _} = list |> List.pop_at(index)
    value
  end

  defp en_name(str, code, courses) do
    case courses
        |> Enum.filter(fn x ->
          String.equivalent?(code, x.code)
        end)
        |> List.first do
      nil -> str
      %{code: _, en_name: en_name} -> en_name
    end
  end

  defp property_en("必修"), do: "MR"
  defp property_en("选修"), do: "ME"
  defp property_en("任选"), do: "Free Electives"
  defp property_en("限选"), do: "Limit Electives"
  defp property_en("通识必修课"), do: "GER"
  defp property_en("通识选修课"), do: "GEE"
  defp property_en(other), do: other

end
