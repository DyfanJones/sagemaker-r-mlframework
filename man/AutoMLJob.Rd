% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/automl_automl.R
\name{AutoMLJob}
\alias{AutoMLJob}
\title{AutoMLJob class}
\description{
A class for interacting with CreateAutoMLJob API.
}
\section{Super class}{
\code{\link[sagemaker.common:.Job]{sagemaker.common::.Job}} -> \code{AutoMLJob}
}
\section{Methods}{
\subsection{Public methods}{
\itemize{
\item \href{#method-new}{\code{AutoMLJob$new()}}
\item \href{#method-start_new}{\code{AutoMLJob$start_new()}}
\item \href{#method-describe}{\code{AutoMLJob$describe()}}
\item \href{#method-wait}{\code{AutoMLJob$wait()}}
\item \href{#method-format}{\code{AutoMLJob$format()}}
\item \href{#method-clone}{\code{AutoMLJob$clone()}}
}
}
\if{html}{
\out{<details open ><summary>Inherited methods</summary>}
\itemize{
\item \out{<span class="pkg-link" data-pkg="sagemaker.common" data-topic=".Job" data-id="stop">}\href{../../sagemaker.common/html/.Job.html#method-stop}{\code{sagemaker.common::.Job$stop()}}\out{</span>}
}
\out{</details>}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-new"></a>}}
\if{latex}{\out{\hypertarget{method-new}{}}}
\subsection{Method \code{new()}}{
Initialize AutoMLJob class
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{AutoMLJob$new(sagemaker_session, job_name = NULL, inputs = NULL)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{sagemaker_session}}{(sagemaker.session.Session): A SageMaker Session
object, used for SageMaker interactions (default: None). If not
specified, the one originally associated with the ``AutoMLJob`` instance is used.}

\item{\code{job_name}}{:}

\item{\code{inputs}}{(str, list[str]): Parameters used when called
:meth:`~sagemaker.automl.AutoML.fit`.}
}
\if{html}{\out{</div>}}
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-start_new"></a>}}
\if{latex}{\out{\hypertarget{method-start_new}{}}}
\subsection{Method \code{start_new()}}{
Create a new Amazon SageMaker AutoML job from auto_ml.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{AutoMLJob$start_new(auto_ml, inputs)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{auto_ml}}{(sagemaker.automl.AutoML): AutoML object
created by the user.}

\item{\code{inputs}}{(str, list[str]): Parameters used when called
:meth:`~sagemaker.automl.AutoML.fit`.}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
sagemaker.automl.AutoMLJob: Constructed object that captures
             all information about the started AutoML job.
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-describe"></a>}}
\if{latex}{\out{\hypertarget{method-describe}{}}}
\subsection{Method \code{describe()}}{
Prints out a response from the DescribeAutoMLJob API call.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{AutoMLJob$describe()}\if{html}{\out{</div>}}
}

}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-wait"></a>}}
\if{latex}{\out{\hypertarget{method-wait}{}}}
\subsection{Method \code{wait()}}{
Wait for the AutoML job to finish.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{AutoMLJob$wait(logs = TRUE)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{logs}}{(bool): indicate whether to output logs.}
}
\if{html}{\out{</div>}}
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-format"></a>}}
\if{latex}{\out{\hypertarget{method-format}{}}}
\subsection{Method \code{format()}}{
format class
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{AutoMLJob$format()}\if{html}{\out{</div>}}
}

}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-clone"></a>}}
\if{latex}{\out{\hypertarget{method-clone}{}}}
\subsection{Method \code{clone()}}{
The objects of this class are cloneable with this method.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{AutoMLJob$clone(deep = FALSE)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{deep}}{Whether to make a deep clone.}
}
\if{html}{\out{</div>}}
}
}
}
